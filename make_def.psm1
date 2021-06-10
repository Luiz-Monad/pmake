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
$proj_defines = @(
    "CMAKE_TOOLCHAIN_FILE=$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake",
    "VCPKG_TARGET_TRIPLET=$($conf.abi)",
    "VCPKG_INSTALL_OPTIONS=$($options -join ';')"
) + $proj_defines

Export-ModuleMember -Variable @(
    'src',
    'project_name',
    'target_name',
    'proj_defines',
    'vs_cmake'
) *>&1 | Out-Null
