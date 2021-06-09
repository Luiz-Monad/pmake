[CmdletBinding()]
param()

# pre
Import-Module $PSScriptRoot/make_arch.psm1 -Force
Import-Module $PSScriptRoot/make_msvc_def.psm1 -Force

# make
make `
    -abi 'msvc-android-armeabi' `
    -msvc_arch 'arm' `
    -ndk_arch 'armeabi-v7a' `
    -conf 'debug' `
    -cxx_flags $cxx_flags `
    -c_flags $c_flags `
    -plat_defines $plat_defines

# done
Get-Module -Name make_arch | Remove-module
Get-Module -Name make_msvc_def | Remove-module
