function make {
    [CmdletBinding()]
    param (
    [ScriptBlock] $filter,
    [boolean] $parallel = $true)

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
                param ([string] $scb, [string] $name)
                & $scb -Verbose *>&1 | `
                    Tee-Object -FilePath "out_$($name).txt"
            }
            if ($useJob) {
                Start-Job `
                    -ScriptBlock $block `
                    -ArgumentList @($script, $name) `
                    -WorkingDirectory (Get-Location)
            } else {
                &$block -scb $script -name $name
            }
        }
    if ($useJob) {
        $jobs | Receive-Job -Wait
    } else {
        $jobs
    }
}

Export-ModuleMember -Function make
