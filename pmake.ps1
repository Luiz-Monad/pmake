[CmdletBinding()]
param(
    [Switch][Boolean] $dbg = $false,
    [String] $plat = $null,
    [Switch][Boolean] $all = $false,
    [boolean] $parallel = $true
)

Import-Module "$PSScriptRoot/make_job.psm1" -Force | Out-Null

if ($dbg) {
    make -filter { $_ -like '*-dbg' } -parallel:$parallel
} elseif ($plat) {
    make -filter { $_ -like "*$plat*" } -parallel:$parallel
} elseif ($all) {
    make -filter { $true } -parallel:$parallel
} else {
    make -filter { $_ -like 'msvc-win-amd64-dbg' } -parallel:$parallel
}

Get-Module -Name make_job | Remove-module | Out-Null
