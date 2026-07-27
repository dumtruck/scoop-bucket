#Requires -Version 5.1

function Resolve-VisualStudioInstallation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$RequiredComponents
    )

    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
        throw "Visual Studio Installer's vswhere.exe was not found: $vswhere"
    }

    $arguments = @('-latest', '-prerelease', '-products', '*', '-requires')
    $arguments += $RequiredComponents
    $arguments += @('-property', 'installationPath')

    $installationPath = & $vswhere @arguments | Select-Object -First 1
    $exitCode = $LASTEXITCODE
    if ($null -ne $exitCode -and $exitCode -ne 0) {
        throw "vswhere.exe exited with code $exitCode."
    }
    if ([string]::IsNullOrWhiteSpace($installationPath)) {
        throw "Visual Studio is missing required components: $($RequiredComponents -join ', ')"
    }

    return $installationPath.Trim()
}

function Resolve-MiseExecutable {
    [CmdletBinding()]
    param()

    $mise = Get-Command mise -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $mise) {
        throw "mise is required to provision the source-build toolchain. Install it with 'scoop install main/mise', or use a WinGet/standalone installation available on PATH."
    }

    return $mise.Source
}

function Invoke-MisePowerShellScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Tools,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptPath,

        [string[]]$ScriptArguments = @(),

        [string]$WorkingDirectory = (Split-Path -Parent $ScriptPath)
    )

    $miseExecutable = Resolve-MiseExecutable
    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        throw "Build script was not found: $ScriptPath"
    }
    if (-not (Test-Path -LiteralPath $WorkingDirectory -PathType Container)) {
        throw "Build working directory was not found: $WorkingDirectory"
    }

    $powerShellExecutable = if ($PSVersionTable.PSEdition -eq 'Core') {
        Join-Path $PSHOME 'pwsh.exe'
    } else {
        Join-Path $PSHOME 'powershell.exe'
    }
    if (-not (Test-Path -LiteralPath $powerShellExecutable -PathType Leaf)) {
        throw "PowerShell executable was not found: $powerShellExecutable"
    }

    $resolvedScriptPath = (Resolve-Path -LiteralPath $ScriptPath).Path
    $miseArguments = @('--yes', '--no-config', 'exec')
    $miseArguments += $Tools
    $miseArguments += @(
        '--',
        $powerShellExecutable,
        '-NoLogo',
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        $resolvedScriptPath
    )
    $miseArguments += $ScriptArguments

    $originalLocation = (Get-Location).Path
    try {
        Set-Location -LiteralPath $WorkingDirectory
        & $miseExecutable @miseArguments
        $exitCode = $LASTEXITCODE
    } finally {
        Set-Location -LiteralPath $originalLocation
    }

    if ($exitCode -ne 0) {
        throw "mise-managed build script exited with code $exitCode."
    }
}

function Invoke-WindowsSourceBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$MiseTools,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$VisualStudioComponents,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptPath,

        [string[]]$ScriptArguments = @(),

        [string]$WorkingDirectory = (Split-Path -Parent $ScriptPath)
    )

    $null = Resolve-VisualStudioInstallation -RequiredComponents $VisualStudioComponents
    Invoke-MisePowerShellScript -Tools $MiseTools -ScriptPath $ScriptPath -ScriptArguments $ScriptArguments -WorkingDirectory $WorkingDirectory
}
