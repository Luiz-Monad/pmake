[CmdletBinding()]
param($env)

$vcpkg = $env:VCPKG_ROOT

$proj_defines = @(
    "CMAKE_TOOLCHAIN_FILE=$vcpkg\scripts\buildsystems\vcpkg.cmake"
)

# $cxx_flags = '-std=c++17 -frtti -fexceptions -MP'
# $c_flags = '-std=c11 -MP'
# $final_defines = $proj_defines + @(
#     "CMAKE_CXX_FLAGS=$cxx_flags",
#     "CMAKE_C_FLAGS=$c_flags",
#     "CMAKE_BUILD_TYPE=$conf",
#     "CMAKE_EXPORT_COMPILE_COMMANDS=ON",
#     "CMAKE_LIBRARY_OUTPUT_DIRECTORY=$bin",
#     "CMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY",
#     "HAVE_WORDS_BIGENDIAN=$is_bigendian",
#     "HAVE_bigendian=$is_bigendian"
# ) + (&{ if ($ndk_arch) { @(
#     "ANDROID_ABI=$ndk_arch",
#     "ANDROID_NDK=$ndk_root/$ndk_version",
#     "ANDROID_PLATFORM=android-$system_version",
#     "ANDROID_STL_TYPE=c++_static",
#     "CMAKE_ANDROID_ARCH_ABI=$ndk_arch",
#     "CMAKE_ANDROID_NDK=$ndk_root/$ndk_version",
#     "CMAKE_SYSTEM_NAME=Android",
#     "CMAKE_SYSTEM_VERSION=$system_version"
# )}}) + (&{ if ($ndk_arch -and (-not $msvc_arch)) { @(
#     "CMAKE_MAKE_PROGRAM=$ninja"
# )}}) + (&{ if ($ndk_arch -and $msvc_arch) { @(
#     "NDK_ROOT=$ndk_root/$ndk_version"
# )}}) + $plat_defines + $proj_defines


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
