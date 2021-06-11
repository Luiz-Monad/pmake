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

    Write-Host -ForegroundColor Cyan "[PMake] Version 0.4"

    $jobs = `
        Get-ChildItem "$env:VCPKG_OVERLAY_TRIPLETS/*.cmake" |
        Where-Object { ($_.BaseName -split '-').Count -eq 3 } |
        ForEach-Object { $_.BaseName + '-rel'; $_.BaseName + '-dbg' } |
        Where-Object -FilterScript $filter |
        ForEach-Object `
    {
        $pargs = @{
            abi        = ($_ -split "-(rel|dbg)")[0]
            conf       = if ($_ -like "*-dbg") { 'debug' } else { 'release' }
            core       = "$PSScriptRoot/make_arch.psm1"
            proj_root  = $root
            trace      = $trace
            trycompile = $trycompile
        }
        $block = [ScriptBlock] {
            [CmdletBinding()]
            param ($pargs)

            $logfile = "$($pargs.proj_root)/out-$($pargs.abi)-$($pargs.conf).txt"

            Import-Module ($pargs.core) -Force *>&1 | Out-Null
            $pargs.Remove('core')
            
            Start-Transcript -Path $logfile
            Invoke-Make @pargs
            Stop-Transcript
        }
        if ($export) {

            Import-Module ($pargs.core) -Force *>&1 | Out-Null
            $pargs.Remove('core')

            Export-CMakeSettings @pargs

        }
        elseif (-not $no_parallel) {
            Start-Job `
                -ScriptBlock $block `
                -ArgumentList @($pargs) `
                -WorkingDirectory (Get-Location) `
                -Verbose:$VerbosePreference
        }
        else {
            & $block $pargs
        }
    }
    if ($export) {
        $src = ($jobs.environments[0].P_project_source)
        ConvertTo-Json -Depth 5 @{ 
            environments   = @(, $jobs.environments[0])
            configurations = $jobs.configurations
        } | Out-File "$src/CMakeSettings.json"
    }
    elseif (-not $no_parallel) {
        $jobs | Receive-Job -Wait
    }
    else {
        $jobs
    }
}

Export-ModuleMember -Function Invoke-Make *>&1 | Out-Null
