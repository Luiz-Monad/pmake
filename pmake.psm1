
Import-Module "$PSScriptRoot/pmake_job.psm1" -Force *>&1 | Out-Null

function Invoke-PMake {
    [CmdletBinding()]
    param (
        [String] $target = $null,
        [String] $root = $null,
        [Switch] $dbg,
        [Switch] $all,
        [Switch] $no_parallel,
        [Switch] $export,
        [Switch] $trace,
        [Switch] $trace_expand,
        [Switch] $debug_trycompile,
        [Switch] $debug_find
    )

    if (-not $root) {
        $root = (Get-Location)
    }

    if ($dbg) {
        $filter = { $_ -like '*-dbg' }
    }
    elseif ($target) {
        $filter = { $_ -like "*$target*" }
    }
    elseif ($all) {
        $filter = { $true }
    }
    else {
        $filter = { $_ -like 'msvc-win-amd64-dbg' }
    }

    Invoke-PMakeBuild `
        -root:$root `
        -filter:$filter `
        -no_parallel:$no_parallel `
        -export:$export `
        -trace:$trace `
        -trace_expand:$trace_expand `
        -debug_trycompile:$debug_trycompile `
        -debug_find:$debug_find `
        -Verbose:$VerbosePreference `
        -Debug:$DebugPreference

}

Export-ModuleMember -Function Invoke-PMake *>&1 | Out-Null
