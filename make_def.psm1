[CmdletBinding()]
param($conf)

$override = "$($conf.proj_root)/pmake_def.psm1"
if (Test-Path $override) {
    Import-Module $override -Force -ArgumentList @($conf)
}

$options =  @(
    "--x-buildtrees-root=$env:X_buildtrees_root",
    "--x-packages-root=$env:X_packages_root"
)
$defines = @(
    "CMAKE_TOOLCHAIN_FILE=$PSScriptRoot/toolchain.cmake",
    "PMAKE_CHAINLOAD_TOOLCHAIN_FILE=$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake",
    "VCPKG_TARGET_TRIPLET=$($conf.abi)",
    "VCPKG_INSTALL_OPTIONS=$($options -join ';')"
) + $defines

Export-ModuleMember -Variable @(
    'source',
    'project_name',
    'target_name',
    'defines'
) *>&1 | Out-Null
