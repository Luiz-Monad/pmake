
$script:_args = @()

function Clear-Arguments { 
    $script:_args = $Null
}

function Push-Arguments { 
    param($k, $v)
    $script:_args = $script:_args + @($k, $v)
}

function Get-Arguments { 
    $_args = $script:_args
    $script:_args = $Null
    $_args
}

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
            -find 'Common7/IDE/CommonExtensions/Microsoft/CMake/**/cmake.exe'
    }
    $script:_cmake
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

function Get-CustomCMake {
    param([String] $build)
    (Join-Path (Get-Item $build) "cmake/bin/cmake.exe")
}

function Enter-DevShell {
    $module = Get-DevShell
    $vsinstall = Get-VsInstallPath
    Import-module $module | Out-Null
    Push-Location
    Enter-VsDevShell -VsInstallPath $vsinstall | Out-Null
    Pop-Location
}

function Write-Log { 
    param($obj, [Switch] $success)
    if ($success) { 
        Write-Host -ForegroundColor Green $obj
    }
    else {
        Write-Host -ForegroundColor Cyan $obj
    }
}

function Write-Arguments {
    param($exe, $first_arg, $exe_args)
    Write-Log $exe
    $l = @("  ", $first_arg);
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

function Get-MsVcArch {
    param([String] $abi)
    switch ($abi) {
        ('msvc-android-amd64') { 'x64' }
        ('msvc-android-x86') { 'x86' }
        ('msvc-android-aarch64') { 'arm64' }
        ('msvc-android-armeabi') { 'arm' }
        ('msvc-win-amd64') { 'x64' }
        ('msvc-win-x86') { 'x86' }
        ('msvc-win-aarch64') { 'arm64' }
        ('msvc-win-armeabi') { 'arm' }
    }
}

function Invoke-CMake { 
    [CmdLetBinding()] param (
        [Parameter(Mandatory = $true)][String] $cmake
    )
    $cmake_args = Get-Arguments
    $source = $cmake_args | Select-Object -First 1
    $cmake_args = $cmake_args | Select-Object -Skip 1
    Write-Arguments `
        -exe $cmake `
        -first_arg $source `
        -exe_args $cmake_args
    & $cmake (@($source) + $cmake_args)
}

function Invoke-Make {
    [CmdletBinding()]
    param (
        [String] $abi,
        [String] $conf,
        [Switch][Boolean] $trace,
        [Switch][Boolean] $trycompile
    )

    Write-Log "[PMake] Building $abi"

    $pjob = $env:VCPKG_MAX_CONCURRENCY

    # options

    $is_android = "$abi".Contains('android')
    $is_windows = "$abi".Contains('win')
    $is_emscripten = "$abi".Contains('wasm')
    $is_msvc = "$abi".Contains('msvc')
    $vs_cmake = $true
    
    # project overriden parameters:

    Import-Module $PSScriptRoot/make_def.psm1 -Force -ArgumentList @{
        'abi'           = $abi;
        'is_android'    = $is_android;
        'is_windows'    = $is_windows;
        'is_emscripten' = $is_emscripten;
        'is_msvc'       = $is_msvc;
    }

    # paths

    $build = $env:P_project_build
    $out = $env:P_project_output
    $target = (New-Item -ItemType Directory "$build/$target_name/$abi-$conf" -Force).FullName
    $bin = (New-Item -ItemType Directory "$out/$target_name/$abi-$conf" -Force).FullName
    $lib = (New-Item -ItemType Directory $bin/lib -Force).FullName
    $src = (Get-Item $src).FullName

    # configuration

    if ($vs_cmake) {
        $cmake = Get-CMake
    }
    else {
        $cmake = Get-CustomCMake -build $build
    }

    if ($is_msvc) {
        Enter-DevShell
    }

    # generate

    Write-Log "[PMake] Generating $abi"

    Clear-Arguments
    Push-Arguments     $src
    Push-Arguments     '-B' $target
    foreach ($define in $proj_defines) { 
        Push-Arguments '-D' $define 
    }
    if ($is_msvc) { 
        Push-Arguments '-G' 'Visual Studio 16 2019'
        Push-Arguments '-A' (Get-MsVcArch $abi)
    }
    else {
        Push-Arguments '-G' 'Ninja'
    }
    if ($trace) {
        Push-Arguments '--trace'
    }
    if ($trycompile) {
        Push-Arguments '--debug-trycompile'
    }    
    Invoke-CMake -cmake $cmake | Out-Host
    if ($LASTEXITCODE -ne 0) { return }

    # make

    Write-Log "[PMake] Making $abi"
    
    Clear-Arguments
    Push-Arguments '--build' $target
    Push-Arguments '--config' $conf
    Push-Arguments '--target' 'install'
    Push-Arguments '--parallel' "$pjob"
    Push-Arguments '-D' "CMAKE_BUILD_TYPE=$conf"
    Push-Arguments '-D' "CMAKE_INSTALL_PREFIX=$bin"
    Invoke-CMake -cmake $cmake | Out-Host
    if ($LASTEXITCODE -ne 0) { return }

    # deploy
    return;
    Write-Log "[PMake] Deploy $abi"
    
    Clear-Arguments
    Push-Arguments '--install' $target
    Push-Arguments '--prefix' $bin
    Push-Arguments '--config' $conf
    Invoke-CMake -cmake $cmake | Out-Host
    if ($LASTEXITCODE -ne 0) { return }

    # symlink static libs

    Get-ChildItem -Path $target -Include ("*.a", "*.lib", "*.pdb") `
        -Recurse | ForEach-Object `
    {
        $s = $_
        $t = Join-Path $lib $_.Name
        If (-not (Test-Path $t)) {
            New-Item -ItemType SymbolicLink -Path $t -Target $s -Verbose | Out-Null
        }
        else {
            Write-Verbose "symlink $t"
        }
    }

    # done
    
    Write-Log -Success "[PMake] Build $abi $conf Ok"

}

Export-ModuleMember -Function Invoke-Make *>&1 | Out-Null
