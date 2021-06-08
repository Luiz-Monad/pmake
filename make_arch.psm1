function make {
    [CmdletBinding()]
    param (
    [string] $abi,
    [string] $msvc_arch,
    [string] $ndk_arch,
    [string] $conf,
    [string] $cxx_flags,
    [string] $c_flags,
    [string[]] $plat_defines)

    # project

    $is_arm = "$msvc_arch,$ndk_arch".Contains('arm')
    $is_windows = "$abi".Contains('win')
    $is_emscripten = "$abi".Contains('wasm')
    $bigendian = (&{ if ($is_arm) {'ON'} else {'OFF'} })
    
    # overriden parameters:

    Import-Module $PSScriptRoot/make_def.psm1 -Force -ArgumentList @{
      'is_arm' = $is_arm;
      'is_windows' = $is_windows;
      'is_emscripten' = $is_emscripten;
      'msvc_arch' = $msvc_arch;
      'ndk_arch' = $ndk_arch;
    }

    # pre

    $target = (New-Item -ItemType Directory "$build/$($target_name)_$($abi)_$conf" -Force).FullName
    $bin = (New-Item -ItemType Directory "$out/$($target_name)_$($abi)_$conf" -Force).FullName
    $lib = (New-Item -ItemType Directory $bin/lib -Force).FullName

    $vswhere = "C:/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
    $msbuild = & $vswhere -latest -requires Microsoft.Component.MSBuild -find "MSBuild/**/Bin/MSBuild.exe"
    if ($vs_cmake) {
        $cmake = & $vswhere -latest -requires Microsoft.VisualStudio.Component.VC.CMake.Project -find "Common7/IDE/CommonExtensions/Microsoft/CMake/**/cmake.exe"
    } else {
        $cmake = (Join-Path (Get-Item $out) "cmake/bin/cmake.exe")
    }
    if ($msvc_arch) {
        $module = & $vswhere -latest -requires Microsoft.Component.MSBuild -find "Common7/Tools/Microsoft.VisualStudio.DevShell.dll"
        $vsinstall = & $vswhere -latest -property installationPath
        Import-module $module
        Push-Location
        Enter-VsDevShell -VsInstallPath $vsinstall | Out-Null
        Pop-Location
    }

    # configuration

    $src = (Get-Item $src).FullName

    $final_defines = $proj_defines + @(
        "CMAKE_CXX_FLAGS=$cxx_flags",
        "CMAKE_C_FLAGS=$c_flags",
        "CMAKE_BUILD_TYPE=$conf",
        "CMAKE_EXPORT_COMPILE_COMMANDS=ON",
        "CMAKE_LIBRARY_OUTPUT_DIRECTORY=$bin",
        "CMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY",
        "HAVE_WORDS_BIGENDIAN=$bigendian",
        "HAVE_bigendian=$bigendian"
    ) + (&{ if ($ndk_arch) { @(
        "ANDROID_ABI=$ndk_arch",
        "ANDROID_NDK=$ndk_root/$ndk_version",
        "ANDROID_PLATFORM=android-$system_version",
        "ANDROID_STL_TYPE=c++_static",
        "CMAKE_ANDROID_ARCH_ABI=$ndk_arch",
        "CMAKE_ANDROID_NDK=$ndk_root/$ndk_version",
        "CMAKE_SYSTEM_NAME=Android",
        "CMAKE_SYSTEM_VERSION=$system_version"
    )}}) + (&{ if ($ndk_arch -and (-not $msvc_arch)) { @(
        "CMAKE_MAKE_PROGRAM=$ninja"
    )}}) + (&{ if ($ndk_arch -and $msvc_arch) { @(
        "NDK_ROOT=$ndk_root/$ndk_version"
    )}}) + $plat_defines + $proj_defines

    $arguments = @(
        '-B', $target
        #, '--trace' #, '--debug-trycompile'
    ) + (
        $final_defines | ForEach-Object { @( 
        '-D', $_ 
    )}) + (&{if ($msvc_arch) { @(
        '-G', 'Visual Studio 16 2019',
        '-A', "$msvc_arch"
    )} else { @(
        '-G', 'Ninja'
    )}})

    # make

    Write-Host -ForegroundColor Cyan $cmake
    $l = @("  ", $src); 
    $arguments | ForEach-Object { 
        if ($_.StartsWith('-')) { 
            Write-Host -ForegroundColor Cyan "$l"; $l = @($_) } 
        else { 
            $l = $l + @($_) } 
    }
    Write-Host -ForegroundColor Cyan "$l"

    & $cmake `
        $src $arguments

    if ($LASTEXITCODE -ne 0) { return }

    # build

    # & $cmake `
    #     --build $target `
    #     --config $conf `
    #     --target install `
    #     --parallel 10 `
    #     "-DCMAKE_BUILD_TYPE=$conf" `
    #     "-DCMAKE_INSTALL_PREFIX=$bin"

    if ($msvc_arch) {
        & $msbuild `
            "$target/$($project_name).sln" `
            -maxCpuCount:10 `
            -p:Configuration=$conf `
            -detailedSummary
    } else {
        & $ninja `
            -f "$target/build.ninja" `
            -C $target `
            -j 10 `
            -v
    }

    if ($LASTEXITCODE -ne 0) { return }

    # deploy

    & $cmake `
        --install $target `
        --prefix $bin `
        --config $conf

    if ($LASTEXITCODE -ne 0) { return }

    # symlink static libs

    Get-ChildItem -Path $target -Include ("*.a", "*.lib", "*.pdb") `
        -Recurse | ForEach-Object {
        $s = $_
        $t = Join-Path $lib $_.Name
        If (-not (Test-Path $t)) {
            New-Item -ItemType SymbolicLink -Path $t -Target $s -Verbose | Out-Null
        } else {
            Write-Verbose "symlink $t"
        }
    }

    # done
    Write-Host -ForegroundColor Cyan "Build $abi $conf Ok"

}

Export-ModuleMember -Function make
