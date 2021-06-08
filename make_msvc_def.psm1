[CmdletBinding()]
param()

$cxx_flags = '-std=c++17 -frtti -fexceptions -MP'
$c_flags = '-std=c11 -MP'
$plat_defines = @()

$override = (Join-Path (Get-Location) "make_ndk_def.psm1")
if (Test-Path $override) {
    Import-Module $override -Force
}

Export-ModuleMember -Variable @('*_flags', '*_defines')
