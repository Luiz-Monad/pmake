[CmdletBinding()]
param()

# pre
Import-Module $PSScriptRoot/make_arch.psm1 -Force
Import-Module $PSScriptRoot/make_ndk_def.psm1 -Force

# make
make `
    -abi 'ndk-android-aarch64' `
    -msvc_arch $null `
    -ndk_arch 'arm64-v8a' `
    -conf 'release' `
    -cxx_flags $cxx_flags `
    -c_flags $c_flags `
    -plat_defines $plat_defines

# done
Get-Module -Name make_arch | Remove-module
Get-Module -Name make_ndk_def | Remove-module
