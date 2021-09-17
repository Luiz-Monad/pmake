
function vcpkg_patch_apply {
    # Apply patches from the ports to the local repository.
    param ($reset = $false, $commit = $true)
    if (-not (Test-Path "vcpkg.json")) {
        Write-Error "vcpkg manifest not found"
        return
    }
    $vcpkg = Get-Content "vcpkg.json" | ConvertFrom-Json
    if ($reset) {
        git reset --hard HEAD
    }
    $port = $vcpkg.name
    $s = Get-ChildItem "$env:VCPKG_OVERLAY_PORTS/$port/*.patch" | Sort-Object
    foreach ($i in $s) {
        Write-Host -ForegroundColor Cyan $i
        git apply $i --verbose
        if ($LASTEXITCODE -ne 0) {throw $LASTEXITCODE}
    }
    if ($commit) {
        git add *
        git commit -m "patched"
    }
}

Export-ModuleMember -Function vcpkg_patch_apply *>&1 | Out-Null

###########################################################################################################################################

function vcpkg_refresh_port_overlay {
    # Copy ports to the overlay for used packages.
    $p = $env:VCPKG_OVERLAY_PORTS
    Get-ChildItem $env:X_buildtrees_root `
        -Exclude @('detect_compiler') |
        Select-Object -Expand name | ForEach-Object {
            Write-Host -ForegroundColor Cyan $_
            if (-not (Test-Path "$p/$_")) {
                Copy-Item "$env:VCPKG_ROOT/ports/$_" `
                    -Destination $p -Recurse -Force -Verbose
            }
        }
}

Export-ModuleMember -Function vcpkg_refresh_port_overlay *>&1 | Out-Null

###########################################################################################################################################

function vcpkg_json_fix_local {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string] $json_string
    )
    $json = ConvertFrom-Json $json_string -NoEnumerate -Depth 100
    $deps = @()
    foreach($dep in $json.dependencies) {
        $d = $dep
        if ($dep.name -and ($dep.name -match "[-]local")) {
            $dep.name = $dep.name -replace "-local", ""
        }
        if ($dep -match "[-]local") {
            $d = $dep -replace "-local", ""
        }
        $deps = $deps + @($d)
    }
    $json.dependencies = $deps
    ConvertTo-Json $json -Depth 100
}

function vcpkg_json_add_local_generator {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string] $json_string
    )
    $json = ConvertFrom-Json $json_string -NoEnumerate -Depth 100
    $json.dependencies = @(@{name='pmake-vcpkg-local'; host=$true}) + $json.dependencies
    $json.name = $json.name + '-local'
    ConvertTo-Json $json -Depth 100
}

function vcpkg_generate_local {
    [CmdLetBinding()]
    param ($port, $base)
    Write-Verbose "port-name: $port"
    Write-Verbose "port-base: $base"
    "pmake_generate_local_finder(NAME $port BASE_DIR $base)`n"
}

function vcpkg_export_port_overlay {
    # Export thirdyparties as port overlays.
    $p = $env:VCPKG_OVERLAY_PORTS
    Get-ChildItem $thirdy_path -Recurse -Depth 1 -Include 'pmake_def.psm1' |
        ForEach-Object {
            $dir = $_.Directory
            Write-Host -ForegroundColor Cyan $dir.BaseName

            Push-Location $dir.FullName
            $src = $null
            $source = $null
            $port_name = $null
            $port_namespace = $null
            Import-Module $_ -Force -Scope Local
            if (Test-Path $source) {
                $src = (Get-Item $source).FullName
            }
            Pop-Location

            if ($port_name) {
                $port = $port_name
            } else {
                $port = $dir.BaseName
            }

            if ($port_namespace) {
                $ns = $port_namespace
            } else {
                $ns = $dir.BaseName
            }

            $vcpkg = "$src/vcpkg.json"
            $portfile = "$src/portfile.cmake"
            $out = "$p/$port"
            $local = "$out-local"

            if ($src -and (Test-Path $vcpkg)) {
                $base = (Get-Item $src).BaseName

                New-Item -ItemType Directory -Force -Path $out | Out-Null
                New-Item -ItemType Directory -Force -Path $local | Out-Null

                # port-file
                Copy-Item $portfile -Destination $out -Force -Verbose
                
                # package-control
                Get-Content $vcpkg -Raw |
                    vcpkg_json_fix_local |
                    Out-File -Path "$out/vcpkg.json" -Encoding utf8nobom -Verbose

                # port-file for local
                vcpkg_generate_local -port $ns -base $base -Verbose |
                    Out-File -Path "$local/portfile.cmake" -Encoding utf8nobom -Verbose

                # package-control for local
                Get-Content $vcpkg -Raw |
                    vcpkg_json_add_local_generator |
                    Out-File -Path "$local/vcpkg.json" -Encoding utf8nobom -Verbose
                

            }
        }
}

Export-ModuleMember -Function vcpkg_export_port_overlay *>&1 | Out-Null

###########################################################################################################################################
