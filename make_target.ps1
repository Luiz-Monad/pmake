[CmdletBinding()]
param($abi, $conf)

# pre
Import-Module $PSScriptRoot/make_arch.psm1 -Force

# make
make `
    -abi $abi `
    -conf $conf

# done
Get-Module -Name make_arch | Remove-module
