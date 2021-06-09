function make {
    [CmdletBinding()]
    param (
    [ScriptBlock] $filter,
    [boolean] $parallel)

    Write-Host -ForegroundColor Cyan "[PMake] Version 0.1"

    $abis = Get-ChildItem "$env:VCPKG_OVERLAY_TRIPLETS/*.cmake" |
        ForEach-Object { $_.BaseName; $_.BaseName + "-dbg" }
    $jobs = $abis | 
        Where-Object -FilterScript $filter |
        ForEach-Object {
            $abi = ($_ -split "-dbg")[0]
            $conf = if ($_ -like "*-dbg") {'release'} else {'debug'}
            $make_target = `
                Join-Path $PSScriptRoot "make_target.ps1" |
                Get-Item
            $logfile = (Join-Path $PSScriptRoot "out-$abi-$conf.txt")
            $script = $make_target.FullName
            $block = [ScriptBlock] {
                [CmdletBinding()]
                param ($scb, $abi, $conf, $logfile)
                & $scb $abi $conf |
                    Tee-Object -FilePath $logfile |
                    Out-Host
            }
            if ($parallel) {
                Start-Job `
                    -ScriptBlock $block `
                    -ArgumentList @($script, $abi, $conf, $logfile) `
                    -WorkingDirectory (Get-Location) `
                    -Verbose:$VerbosePreference
            } else {
                & $block -scb $script -abi $abi -dbg $conf -logfile $logfile
            }
        }
    if ($parallel) {
        $jobs | Receive-Job -Wait
    } else {
        $jobs
    }
}

Export-ModuleMember -Function make *>&1 | Out-Null
