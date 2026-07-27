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

Describe 'Invoke-MisePowerShellScript' {
    It 'reports a missing mise command before validating build paths' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'mise' }

        {
            Invoke-MisePowerShellScript -Tools 'node@22' -ScriptPath 'missing-build.ps1'
        } | Should -Throw '*mise is required*'
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
