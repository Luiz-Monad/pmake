
Import-Module "$PSScriptRoot/pmake_helper.psm1" -Force *>&1 | Out-Null

function Invoke-Make {
    [CmdletBinding()]
    param (
        [String] $root,
        [ScriptBlock] $filter,
        [Switch][Boolean] $no_parallel,
        [Switch][Boolean] $trace,
        [Switch][Boolean] $trycompile,
        [Switch][Boolean] $export
    )

    Write-Host -ForegroundColor Cyan "[PMake] Version 0.7"

    $jobs = `
        Get-ChildItem "$env:VCPKG_OVERLAY_TRIPLETS/*.cmake" | `
        Where-Object { ($_.BaseName -split '-').Count -eq 3 } | `
        ForEach-Object { $_.BaseName + '-rel'; $_.BaseName + '-dbg' } | `
        Where-Object -FilterScript $filter | `
        ForEach-Object `
    {
        $pargs = @{
            abi        = ($_ -split "-(rel|dbg)")[0]
            conf       = if ($_ -like "*-dbg") { 'debug' } else { 'release' }
            core       = "$PSScriptRoot/make_cmake.psm1"
            helper     = "$PSScriptRoot/pmake_helper.psm1"
            proj_root  = $root
            trace      = $trace
            trycompile = $trycompile
            Verbose    = $VerbosePreference
            Debug      = $DebugPreference
        }
        if ($export) {

            Import-Module ($pargs.helper) -Force *>&1 | Out-Null
            $pargs.Remove('helper')
            
            Import-Module ($pargs.core) -Force *>&1 | Out-Null
            $pargs.Remove('core')

            Export-CMakeSettings @pargs

        }
        else {
            $block = [ScriptBlock] {
                [CmdletBinding()]
                param ($pargs) 

                Import-Module ($pargs.helper) -Force *>&1 | Out-Null
                $pargs.Remove('helper')

                Import-Module ($pargs.core) -Force *>&1 | Out-Null
                $pargs.Remove('core')

                if ($pargs.trace) {
                    Write-Verbose "[PMake] Tracing..."
                }

                $logfile = "$($pargs.proj_root)/out-$($pargs.abi)-$($pargs.conf).txt"
                Set-ProcessTranscript $logfile

                Invoke-Make @pargs

                Set-ProcessTranscript $null
            }
            if (-not $no_parallel) {
                Invoke-ThreadJob `
                    -Verbose:$VerbosePreference `
                    -Debug:$DebugPreference `
                    -Name "InvokeMake" `
                    -ScriptBlock $block `
                    -ArgumentList $pargs
            }
            else {
                & $block $pargs
            }
        }
    }
    if ($export) {
        $src = ($jobs.environments[0].P_project_source)
        ConvertTo-Json -Depth 5 @{ 
            environments   = @(, $jobs.environments[0])
            configurations = $jobs.configurations
        } | Out-File "$src/CMakeSettings.json"
    }
}

Export-ModuleMember -Function Invoke-Make *>&1 | Out-Null
