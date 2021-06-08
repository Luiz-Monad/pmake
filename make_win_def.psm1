[CmdletBinding()]
param()

$cxx_flags = '/std:c++17 /GR /EHsc /openmp /MP'
$c_flags = '/std:c11 /GR /MP'
$plat_defines = @()

$override = (Join-Path (Get-Location) "make_win_def.psm1")
if (Test-Path $override) {
    Import-Module $override -Force
}

Export-ModuleMember -Variable @('*_flags', '*_defines')
