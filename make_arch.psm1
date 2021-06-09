
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
        [Parameter(ParameterSetName="1")][String] $component,
        [Parameter(ParameterSetName="1")][String] $find,
        [Parameter(ParameterSetName="2")][String] $property
    )
    $vswhere = "C:/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
    if ($find) {
        & $vswhere -latest -requires $component -find $find
    } elseif ($property) {
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
    param($build)
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
    param($obj, [Switch]$success)
    if ($success) { 
        Write-Host -ForegroundColor Green $obj
    } else {
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
        } else { 
            $l = $l + @($_) 
        } 
    }
    Write-Log "$l"
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

function Get-MsVcArch {
    param($abi)
    switch ($abi) {
        ('msvc-win-amd64') { 'x64' }
        ('msvc-win-x86') { 'x86' }
        ('msvc-android-amd64') { 'x64' }
        ('msvc-android-x86') { 'x86' }
        ('msvc-android-aarch64') { 'arm64' }
        ('msvc-android-armeabi') { 'arm' }
    }
}
function make {
    [CmdletBinding()]
    param (
    [string] $abi,
    [string] $conf)

    Write-Log "[PMake] Building $abi"

    # options

    $is_android = "$abi".Contains('android')
    $is_windows = "$abi".Contains('win')
    $is_emscripten = "$abi".Contains('wasm')
    $is_msvc = "$abi".Contains('msvc')
    $vs_cmake = $true
    
    # project overriden parameters:

    Import-Module $PSScriptRoot/make_def.psm1 -Force -ArgumentList @{
      'is_android' = $is_android;
      'is_windows' = $is_windows;
      'is_emscripten' = $is_emscripten;
      'is_msvc' = $is_msvc;
    }

    # paths

    $target = (New-Item -ItemType Directory "$build/$target_name/$abi-$conf" -Force).FullName
    $bin = (New-Item -ItemType Directory "$out/$target_name/$abi-$conf" -Force).FullName
    $lib = (New-Item -ItemType Directory $bin/lib -Force).FullName
    $src = (Get-Item $src).FullName

    # configuration

    if ($vs_cmake) {
        $cmake = Get-CMake
    } else {
        $cmake = Get-CustomCMake -build $build
    }

    if ($is_msvc) {
        Enter-DevShell
    }

    # generate

    Write-Log "[PMake] Generating $abi"

    $final_defines = $proj_defines

    Clear-Arguments
    Push-Arguments     $src
    Push-Arguments     '-B' $target
    if ($is_trace) {
        Push-Arguments '--trace'
    }
    if ($is_debug_trycompile) {
        Push-Arguments '--debug-trycompile'
    }
    foreach ($define in $final_defines) { 
        Push-Arguments '-D' $define 
    }
    if ($is_msvc) { 
        Push-Arguments '-G' 'Visual Studio 16 2019'
        Push-Arguments '-A' (Get-MsVcArch $abi)
    } else {
        Push-Arguments '-G' 'Ninja'
    }
    Invoke-CMake -cmake $cmake | Out-Host

    if ($LASTEXITCODE -ne 0) { return }
    return

    # make

    Write-Log "[PMake] Making $abi"
    
    # & $cmake `
    #     --build $target `
    #     --config $conf `
    #     --target install `
    #     --parallel 10 `
    #     "-DCMAKE_BUILD_TYPE=$conf" `
    #     "-DCMAKE_INSTALL_PREFIX=$bin"

    if ($LASTEXITCODE -ne 0) { return }

    # deploy

    Write-Log "[PMake] Deploy $abi"
    
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
    
    Write-Log -Success "[PMake] Build $abi $conf Ok"

}

Export-ModuleMember -Function make | Out-Null
