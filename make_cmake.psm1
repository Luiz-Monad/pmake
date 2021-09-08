
Import-Module "$PSScriptRoot/pmake_helper.psm1" -Force *>&1 | Out-Null

function Write-Log {
    param($obj, [Switch] $success)
    if ($success) {
        Write-Host -ForegroundColor Green $obj
    }
    else {
        Write-Host -ForegroundColor Cyan $obj
    }
}

###########################################################################################################################################

$script:_args = @()

function Clear-Arguments {
    $script:_args = $Null
}

function Push-Arguments {
    param($k, $v = $null)
    $script:_args = $script:_args + @($k)
    if ($v) {
        $script:_args = $script:_args + @($v)
    }
}

function Get-Arguments {
    $_args = $script:_args
    $script:_args = $Null
    $_args
}

function Write-Arguments {
    param($exe, $exe_args)
    $l = @($exe);
    $exe_args | ForEach-Object {
        if ($_.StartsWith('-')) {
            Write-Log "$l"; $l = @($_)
        }
        else {
            $l = $l + @($_)
        }
    }
    Write-Log "$l"
}

###########################################################################################################################################

function Get-VsWhere {
    param (
        [Parameter(ParameterSetName = "1")][String] $component,
        [Parameter(ParameterSetName = "1")][String] $find,
        [Parameter(ParameterSetName = "2")][String] $property
    )
    $vswhere = "C:/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
    if ($find) {
        & $vswhere -latest -requires $component -find $find
    }
    elseif ($property) {
        & $vswhere -latest -property $property
    }
}

function Get-MsBuild {
    if (-not $script:_msbuild) {
        $script:_msbuild = Get-VsWhere `
            -component 'Microsoft.Component.MSBuild' `
            -find 'MSBuild/**/Bin/MSBuild.exe'
    }
    $script:_msbuild
}

function Get-CMake {
    if (-not $script:_cmake) {
        $script:_cmake = Get-VsWhere `
            -component 'Microsoft.VisualStudio.Component.VC.CMake.Project' `
            -find 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/**/cmake.exe'
    }
    $script:_cmake
}

function Get-Ninja {
    if (-not $script:_ninja) {
        $script:_ninja = Get-VsWhere `
            -component 'Microsoft.VisualStudio.Component.VC.CMake.Project' `
            -find 'Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/**/ninja.exe'
    }
    $script:_ninja
}

function Get-DevShell {
    if (-not $script:_devshell) {
        $script:_devshell = Get-VsWhere `
            -component 'Microsoft.Component.MSBuild' `
            -find 'Common7/Tools/Microsoft.VisualStudio.DevShell.dll'
    }
    $script:_devshell
}

function Get-VsInstallPath {
    if (-not $script:_vsinstall) {
        $script:_vsinstall = Get-VsWhere `
            -property installationPath
    }
    $script:_vsinstall
}

function Enter-DevShell {
    [CmdLetBinding()] param ()

    $module = Get-DevShell
    Import-module $module | Out-Null
    $vsinstall = Get-VsInstallPath

    Write-Debug "Entering MSVC DevShell"
    $before = Get-Item env:
    
    Push-Location
    Enter-VsDevShell -VsInstallPath $vsinstall | Out-Null
    Pop-Location

    if ($DebugPreference -notmatch '(Ignore|SilentlyContinue)') {
        $after = Get-Item env:
        $diff = $after | Where-Object { $_ -notin $before }
        $diff | Format-Table | Out-String | Write-Debug
    }
}

###########################################################################################################################################

function Get-MsVcArch {
    param([String] $abi)
    switch ($abi) {
        ('msvc-android-amd64') { 'x64' }
        ('msvc-android-x86') { 'x86' }
        ('msvc-android-aarch64') { 'arm64' }
        ('msvc-android-armeabi') { 'arm' }
        ('msvc-windows-amd64') { 'x64' }
        ('msvc-windows-x86') { 'Win32' }
        ('msvc-windows-aarch64') { 'ARM64' }
        ('msvc-windows-armeabi') { 'ARM' }
    }
}

function Get-MsVcGArch {
    param([String] $abi)
    switch ($abi) {
        ('msvc-android-amd64') { '' }
        ('msvc-android-x86') { '' }
        ('msvc-android-aarch64') { '' }
        ('msvc-android-armeabi') { '' }
        ('msvc-windows-amd64') { 'Win64' }
        ('msvc-windows-x86') { '' }
        ('msvc-windows-aarch64') { 'ARM64' }
        ('msvc-windows-armeabi') { 'ARM' }
    }
}

function Get-MsVcIntellisense {
    param([String] $abi)
    switch ($abi) {
        ('ndk-android-amd64') { 'android-clang-x64' }
        ('ndk-android-x86') { 'android-clang-x86' }
        ('ndk-android-aarch64') { 'android-clang-arm64' }
        ('ndk-android-armeabi') { 'android-clang-arm' }
        ('msvc-android-amd64') { 'android-clang-x64' }
        ('msvc-android-x86') { 'android-clang-x86' }
        ('msvc-android-aarch64') { 'android-clang-arm64' }
        ('msvc-android-armeabi') { 'android-clang-arm' }
        ('msvc-windows-amd64') { 'windows-msvc-x64' }
        ('msvc-windows-x86') { 'windows-msvc-x86' }
        ('msvc-windows-aarch64') { 'windows-msvc-arm64' }
        ('msvc-windows-armeabi') { 'windows-msvc-arm' }
        ('clang-windows-amd64') { 'windows-clang-x64' }
        ('clang-windows-x86') { 'windows-clang-x86' }
        ('clang-windows-aarch64') { 'windows-clang-arm64' }
        ('clang-windows-armeabi') { 'windows-clang-arm' }
        ('clang-ios-amd64') { 'ios-clang-x64' }
        ('clang-ios-x86') { 'ios-clang-x86' }
        ('clang-ios-aarch64') { 'ios-clang-arm64' }
        ('clang-ios-armeabi') { 'ios-clang-arm' }
    }
}

###########################################################################################################################################

function Invoke-CMake {
    [CmdLetBinding()] param (
        [Parameter(Mandatory = $true)][String] $cmake
    )
    $cmake_args = Get-Arguments
    Write-Arguments `
        -exe $cmake `
        -exe_args $cmake_args
    $trace = ('--trace' -in $cmake_args)
    Invoke-Process `
        -FilePath $cmake `
        -ArgumentList $cmake_args `
        -Timeout ([TimeSpan]::MaxValue) `
        -Verbose:$VerbosePreference `
        -Debug:$DebugPreference | `
        Write-Object -RedirectError:$trace
}

###########################################################################################################################################

function New-Environment {
    [CmdletBinding()]
    param (
        [String] $abi,
        [String] $conf,
        [String] $proj_root
    )

    # options

    $is_android = "$abi".Contains('android')
    $is_windows = "$abi".Contains('win')
    $is_emscripten = "$abi".Contains('wasm')
    $is_msvc = "$abi".Contains('msvc')

    # project overriden parameters:

    Push-Location $proj_root

    Import-Module $PSScriptRoot/make_def.psm1 -Force -ArgumentList @{
        abi           = $abi
        is_android    = $is_android
        is_windows    = $is_windows
        is_emscripten = $is_emscripten
        is_msvc       = $is_msvc
        proj_root     = $proj_root
    }

    $source = (Get-Item $source).FullName

    Pop-Location

    # modified: 'source'
    # modified: 'project_name'
    # modified: 'target_name'
    # modified: 'defines'

    # environment

    $out = $env:P_project_output
    $build = $env:P_project_build

    @{
        abi           = $abi
        conf          = $conf
        is_android    = $is_android
        is_windows    = $is_windows
        is_emscripten = $is_emscripten
        is_msvc       = $is_msvc
        proj_root     = $proj_root
        proj_name     = $project_name
        proj_defines  = $defines
        target_name   = $target_name

        src           = $source
        tgt           = (New-Item -ItemType Directory "$build/$target_name/$abi-$conf" -Force).FullName
        out           = (New-Item -ItemType Directory "$out/$target_name/$abi-$conf" -Force).FullName

        pjob          = $env:VCPKG_MAX_CONCURRENCY
    }

}

###########################################################################################################################################

function Invoke-Make {
    [CmdletBinding()]
    param (
        [String] $abi,
        [String] $conf,
        [String] $proj_root,
        [Switch] $trace,
        [Switch] $trace_expand,
        [Switch] $debug_trycompile,
        [Switch] $debug_find
    )

    Write-Log "[PMake] Building $abi"

    $env = `
        New-Environment `
        -abi $abi `
        -conf $conf `
        -proj_root $proj_root

    # tool environment

    if ($env.is_msvc) {
        Enter-DevShell #-Debug
    }

    $tri = "$($env.proj_name)-$($env.abi)-$($env.conf)"

    # generate

    Write-Log "[PMake] Generating $tri"

    Clear-Arguments
    Push-Arguments     '-S' $env.src
    Push-Arguments     '-B' $env.tgt
    foreach ($def in $env.proj_defines) {
        Push-Arguments '-D' $def
    }
    if ($env.is_msvc) {
        Push-Arguments '-G' 'Visual Studio 16 2019'
        Push-Arguments '-A' (Get-MsVcArch $env.abi)
    }
    else {
        Push-Arguments '-D' "CMAKE_BUILD_TYPE=$($env.conf)"
        Push-Arguments '-D' "CMAKE_MAKE_PROGRAM=$(Get-Ninja)"
        Push-Arguments '-G' 'Ninja'
    }
    if ($trace) {
        Push-Arguments '--trace'
    }
    if ($trace_expand) {
        Push-Arguments '--trace-expand'
    }
    if ($debug_trycompile) {
        Push-Arguments '--debug-trycompile'
    }
    if ($debug_find) {
        Push-Arguments '--debug-find'
    }
    Invoke-CMake -cmake (Get-CMake)
    if ($LASTEXITCODE -ne 0) { return }

    # make

    Write-Log "[PMake] Making $tri"

    Clear-Arguments
    Push-Arguments '--build' $env.tgt
    Push-Arguments '--config' $env.conf
    Push-Arguments '--parallel' "$($env.pjob)"
    Push-Arguments '-D' "CMAKE_BUILD_TYPE=$($env.conf)"
    Push-Arguments '-D' "CMAKE_INSTALL_PREFIX=$($env.out)"
    if ($trace) {
        Push-Arguments '--trace'
    }
    Invoke-CMake -cmake (Get-CMake)
    if ($LASTEXITCODE -ne 0) { return }

    # deploy

    Write-Log "[PMake] Deploy $tri"

    Clear-Arguments
    Push-Arguments '--install' $env.tgt
    Push-Arguments '--config' $env.conf
    Push-Arguments '--prefix' $env.out
    Invoke-CMake -cmake (Get-CMake)
    if ($LASTEXITCODE -ne 0) { return }

    # done

    Write-Log -Success "[PMake] Build $tri Ok"

}

Export-ModuleMember -Function Invoke-Make *>&1 | Out-Null

###########################################################################################################################################

function Export-CMakeSettings {
    [CmdletBinding()]
    param (
        [String] $abi,
        [String] $conf,
        [String] $proj_root,
        [Switch] $trace,
        [Switch] $trace_expand,
        [Switch] $debug_trycompile,
        [Switch] $debug_find
    )

    Write-Log "[PMake] Exporting $abi-$conf"

    function proper_case { param($s) "$($s.Substring(0,1).ToUpper())$($s.Substring(1).ToLower())" }

    $x = `
        New-Environment `
        -abi $abi `
        -conf $conf `
        -proj_root $proj_root

    $intellisense = (Get-MsVcIntellisense -abi $abi)

    if ($x.is_msvc) {
        $arch = (Get-MsVcGArch -abi $abi)
        $generator = "Visual Studio 16 2019 $arch".Trim()
    }
    else {
        $x.proj_defines = $x.proj_defines + @("CMAKE_MAKE_PROGRAM=$(Get-Ninja)")
        $generator = 'Ninja'
    }

    # Create a CMakeSettings with our environment to use in Visual Studio.

    @{
        "environments"   = @(
            @{
                "environment"                = "pmake"
                "VCPKG_DEFAULT_TRIPLET"      = $env:VCPKG_DEFAULT_TRIPLET
                "VCPKG_DEFAULT_HOST_TRIPLET" = $env:VCPKG_DEFAULT_HOST_TRIPLET
                "VCPKG_OVERLAY_PORTS"        = $env:VCPKG_OVERLAY_PORTS
                "VCPKG_OVERLAY_TRIPLETS"     = $env:VCPKG_OVERLAY_TRIPLETS
                "VCPKG_DOWNLOADS"            = $env:VCPKG_DOWNLOADS
                "VCPKG_ROOT"                 = $env:VCPKG_ROOT
                "VCPKG_DEFAULT_BINARY_CACHE" = $env:VCPKG_DEFAULT_BINARY_CACHE
                "VCPKG_MAX_CONCURRENCY"      = $env:VCPKG_MAX_CONCURRENCY
                "X_buildtrees_root"          = $env:X_buildtrees_root
                "X_install_root"             = $env:X_install_root
                "X_packages_root"            = $env:X_packages_root
                "P_project_build"            = $env:P_project_build
                "P_project_output"           = $env:P_project_output
                "P_project_source"           = $x.src
            }
        )
        "configurations" = @(
            @{
                "name"                = "$($x.abi)-$($x.conf)"
                "generator"           = $generator
                "configurationType"   = (proper_case $x.conf)
                "buildRoot"           = $x.tgt
                "installRoot"         = $x.out
                "intelliSenseMode"    = "$intellisense"
                "inheritEnvironments" = @("pmake")
                "cmakeCommandArgs"    = ""
                "buildCommandArgs"    = ""
                "variables"           = `
                    $x.proj_defines | ForEach-Object {
                    $kv = "$_".Split('=', 2)
                    @{
                        "name"  = $kv[0]
                        "value" = $kv[1]
                        "type"  = "STRING"
                    }
                }
            }
        )
    }
}

Export-ModuleMember -Function Export-CMakeSettings *>&1 | Out-Null

###########################################################################################################################################
