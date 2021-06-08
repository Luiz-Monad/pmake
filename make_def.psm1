[CmdletBinding()]
param($env)

$proj_defines = @(
)

$override = (Join-Path (Get-Location) "make_def.psm1")
if (Test-Path $override) {
    Import-Module $override -Force -ArgumentList @($env)
}

Export-ModuleMember -Variable @(
    'ndk_root',
    'ndk_version',
    'system_version',
    'ninja',
    'project_name',
    'target_name',
    'out',
    'build',
    'src',
    'proj_defines'
)
