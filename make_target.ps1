[CmdletBinding()]
param($abi, $conf)

# pre
Import-Module $PSScriptRoot/make_arch.psm1 -Force *>&1 | Out-Null

# make
make `
    -abi $abi `
    -conf $conf

# done
Get-Module -Name make_arch *>&1 | Remove-module *>&1 | Out-Null
