[CmdletBinding()]
param($env)

$override = (Join-Path (Get-Location) "make_def.psm1")
if (Test-Path $override) {
    Import-Module $override -Force -ArgumentList @($env)
}

$vcpkg = $env:VCPKG_ROOT
$options =  @(
    "--x-buildtrees-root=$env:X_buildtrees_root",
    "--x-packages-root=$env:X_packages_root"
)
$proj_defines = @(
    "CMAKE_TOOLCHAIN_FILE=$vcpkg\scripts\buildsystems\vcpkg.cmake",
    "VCPKG_TARGET_TRIPLET=$($env.abi)",
    "VCPKG_INSTALL_OPTIONS=$($options -join ';')"
) + $proj_defines

Export-ModuleMember -Variable @(
    'project_name',
    'target_name',
    'out',
    'build',
    'src',
    'proj_defines',
    'is_trace'
)
