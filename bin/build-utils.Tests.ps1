BeforeAll {
    . "$PSScriptRoot\build-utils.ps1"
}

Describe 'Resolve-VisualStudioInstallation' {
    It 'reports a missing Visual Studio installer' {
        Mock Test-Path { $false } -ParameterFilter { $LiteralPath -like '*\vswhere.exe' }

        {
            Resolve-VisualStudioInstallation -RequiredComponents 'Microsoft.Component.MSBuild'
        } | Should -Throw '*vswhere.exe was not found*'
    }
}

Describe 'Resolve-MiseExecutable' {
    It 'uses the first mise executable found on PATH' {
        Mock Get-Command {
            @(
                [pscustomobject]@{ Source = 'C:\scoop\shims\mise.exe' }
                [pscustomobject]@{ Source = 'C:\Users\user\AppData\Local\Microsoft\WinGet\Links\mise.exe' }
            )
        } -ParameterFilter { $Name -eq 'mise' }

        Resolve-MiseExecutable | Should -Be 'C:\scoop\shims\mise.exe'
    }
}

Describe 'Invoke-MisePowerShellScript' {
    It 'reports a missing mise command before validating build paths' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'mise' }

        {
            Invoke-MisePowerShellScript -Tools 'node@22' -ScriptPath 'missing-build.ps1'
        } | Should -Throw "*scoop install main/mise*"
    }
}

Describe 'Invoke-WindowsSourceBuild' {
    BeforeEach {
        Mock Resolve-VisualStudioInstallation { 'C:\VisualStudio' }
        Mock Invoke-MisePowerShellScript
    }

    It 'validates Visual Studio components and forwards the mise build request' {
        $parameters = @{
            MiseTools              = @('node@22', 'pnpm@10.17.0')
            VisualStudioComponents = @('Microsoft.Component.MSBuild')
            ScriptPath             = 'C:\source\build.ps1'
            ScriptArguments        = @('-Configuration', 'Release')
            WorkingDirectory       = 'C:\source'
        }

        Invoke-WindowsSourceBuild @parameters

        Should -Invoke Resolve-VisualStudioInstallation -Exactly 1 -ParameterFilter {
            $RequiredComponents -contains 'Microsoft.Component.MSBuild'
        }
        Should -Invoke Invoke-MisePowerShellScript -Exactly 1 -ParameterFilter {
            $Tools -contains 'node@22' -and
            $ScriptPath -eq 'C:\source\build.ps1' -and
            $WorkingDirectory -eq 'C:\source'
        }
    }
}
