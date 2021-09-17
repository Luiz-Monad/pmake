[CmdletBinding()]
param(
    [String] $path,
    [String] $build,
    [String] $out
)

# DirTree
$root_path = (Get-Item $path).FullName
    $ports_path = "$root_path/ports"
    $targets_path = "$root_path/targets"
    $thirdy_path = "$root_path/thirdparty"
        $vcpkg_path = "$thirdy_path/vcpkg"
$build_path = (Get-Item $build).FullName
    $download_path = "$build_path/download"
    $cache_path = "$build_path/caches"
    $proj_build_path = "$build_path/outputs"
$out_path = (Get-Item $out).FullName

###########################################################################################################################################

# Specify the target architecture triplet. See 'vcpkg help triplet'
New-Item -Path env: -Name VCPKG_DEFAULT_TRIPLET -Value x64-windows-static

# Specify the host architecture triplet. See 'vcpkg help triplet'
New-Item -Path env: -Name VCPKG_DEFAULT_HOST_TRIPLET -Value x64-windows-static

# Specify directories to be used when searching for ports
New-Item -Path env: -Name VCPKG_OVERLAY_PORTS -Value $ports_path

# Specify directories containing triplets files
New-Item -Path env: -Name VCPKG_OVERLAY_TRIPLETS -Value $targets_path

# Specify the downloads root directory
New-Item -Path env: -Name VCPKG_DOWNLOADS -Value $download_path

# Specify the vcpkg root directory
New-Item -Path env: -Name VCPKG_ROOT -Value $vcpkg_path

# Binary caching
New-Item -Path env: -Name VCPKG_DEFAULT_BINARY_CACHE -Value $cache_path

# Numer of CPUs to use.
New-Item -Path env: -Name VCPKG_MAX_CONCURRENCY -Value 16

###########################################################################################################################################

# Specify the buildtrees root directory
New-Item -Path env: -Name X_buildtrees_root -Value "$build_path/buildtrees"

# Specify the install root directory
New-Item -Path env: -Name X_install_root -Value "$build_path/install"

# Specify the packages root directory
New-Item -Path env: -Name X_packages_root -Value "$build_path/packages"

###########################################################################################################################################

# Specify the intermediate output directory
New-Item -Path env: -Name P_project_build -Value $proj_build_path

# Specify the final output directory
New-Item -Path env: -Name P_project_output -Value $out_path

###########################################################################################################################################

function vcpkg {
    [CmdLetBinding()] 
    param (
        [Parameter()][String] $target = $null,
        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments)] $vcpkg_args
    )
    $fargs = @( `
        "--triplet=$target",                           # Specify the target architecture triplet.
        "--x-buildtrees-root=$env:X_buildtrees_root",  # Specify the buildtrees root directory
        "--x-install-root=$env:X_install_root",        # Specify the install root directory
        "--x-packages-root=$env:X_packages_root"       # Specify the packages root directory
    ) + $vcpkg_args
    Write-Debug ($fargs -join " ")
    & "$env:VCPKG_ROOT/vcpkg.exe" $fargs
}

Import-Module "$PSScriptRoot/pmake_vcpkg.psm1" -Force *>&1 | Out-Null

###########################################################################################################################################

Import-Module "$PSScriptRoot/pmake.psm1" -Force *>&1 | Out-Null

function pmake {
    [CmdletBinding()]
    param (
        [String] $root = $null,
        [String] $target = $null,
        [Switch] $dbg,
        [Switch] $all,
        [Switch] $no_parallel,
        [Switch] $export,
        [Switch] $trace,
        [Switch] $trace_expand,
        [Switch] $debug_trycompile,
        [Switch] $debug_find
    )
    Invoke-PMake `
        -root:$root `
        -target:$target `
        -dbg:$dbg `
        -all:$all `
        -no_parallel:$no_parallel `
        -export:$export `
        -trace:$trace `
        -trace_expand:$trace_expand `
        -debug_trycompile:$debug_trycompile `
        -debug_find:$debug_find `
        -Verbose:$VerbosePreference `
        -Debug:$DebugPreference
}

###########################################################################################################################################
