function make {
    [CmdletBinding()]
    param (
    [ScriptBlock] $filter,
    [boolean] $parallel)

    Write-Host -ForegroundColor Cyan "[PMake] Version 0.1"

    $abis = Get-ChildItem "$PSScriptRoot/*.ps1" |
        ForEach-Object { $_.BaseName.Replace('make_', '') }
    $jobs = $abis | 
        Where-Object -FilterScript $filter |
        ForEach-Object {
            $abi = $_
            $make_abi = `
                Join-Path $PSScriptRoot "make_$abi.ps1" |
                Get-Item
            $name = $make_abi.BaseName
            $script = $make_abi.FullName
            $block = [ScriptBlock] {
                [CmdletBinding()]
                param ([string] $scb)
                & $scb
            }
            if ($parallel) {
                Start-Job `
                    -ScriptBlock $block `
                    -ArgumentList @($script) `
                    -WorkingDirectory (Get-Location) `
                    -Verbose:$VerbosePreference |
                    Tee-Object -FilePath "out_$name.txt"
            } else {
                & $block -scb $script |
                    Tee-Object -FilePath "out_$name.txt"
            }
        }
    if ($parallel) {
        $jobs | Receive-Job -Wait
    } else {
        $jobs
    }
}

Export-ModuleMember -Function make *>&1 | Out-Null
