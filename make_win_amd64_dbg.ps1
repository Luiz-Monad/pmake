[CmdletBinding()]
param()

# pre
Import-Module $PSScriptRoot/make_arch.psm1 -Force
Import-Module $PSScriptRoot/make_win_def.psm1 -Force

# make
make `
    -abi 'msvc-win-amd64' `
    -msvc_arch 'x64' `
    -ndk_arch $null `
    -conf 'debug' `
    -cxx_flags $cxx_flags `
    -c_flags $c_flags `
    -plat_defines $plat_defines

# done
Get-Module -Name make_arch | Remove-module
Get-Module -Name make_win_def | Remove-module
