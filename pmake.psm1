
Import-Module "$PSScriptRoot/make_job.psm1" -Force *>&1 | Out-Null

function Invoke-PMake {
    [CmdletBinding()]
    param (
    [String] $target = $null,
    [String] $root = $null,
    [Switch][Boolean] $dbg,
    [Switch][Boolean] $all,
    [Switch][Boolean] $no_parallel,
    [Switch][Boolean] $trace,
    [Switch][Boolean] $trycompile)

    if (-not $root) {
        $root = (Get-Location)
    }

    if ($dbg) {
        $filter = { $_ -like '*-dbg' }
    } elseif ($target) {
        $filter = { $_ -like "*$target*" }
    } elseif ($all) {
        $filter = { $true }
    } else {
        $filter = { $_ -like 'msvc-win-amd64-dbg' }
    }
    
    Invoke-Make `
        -root:$root `
        -filter $filter `
        -no_parallel:$no_parallel `
        -trace:$trace `
        -trycompile:$trycompile
    
}

Export-ModuleMember -Function Invoke-PMake *>&1 | Out-Null
