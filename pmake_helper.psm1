
function Invoke-Process {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$FilePath = "PowerShell.exe",

        [Parameter(Mandatory = $false, Position = 1)]
        [string[]]$ArgumentList = @(),
        
        [Parameter(Mandatory = $false, Position = 2)]
        [string]$WorkingDirectory = ".",

        [Parameter(Mandatory = $false, Position = 3)]
        [TimeSpan]$Timeout = [System.TimeSpan]::FromMinutes(2),

        [Parameter(Mandatory = $false, Position = 4)]
        [System.Diagnostics.ProcessPriorityClass]$Priority = [System.Diagnostics.ProcessPriorityClass]::Normal,

        [Parameter(Mandatory = $false, Position = 6)][Switch]
        [Boolean]$RedirectError = $false
    )
    process {
        try {
            $pargs = @{
                FilePath         = $FilePath
                ArgumentList     = $ArgumentList
                WorkingDirectory = $WorkingDirectory
                Timeout          = $Timeout
                Priority         = $Priority
                RedirectError    = $RedirectError
            }
            Write-Debug "Execute command : $WorkingDirectory / $FilePath $ArgumentList "
            $job = Start-ThreadJob `
                -Verbose:$VerbosePreference `
                -Debug:$DebugPreference `
                -Name "InvokeProcess" `
                -ArgumentList @($pargs) `
                -ScriptBlock {
                param($pargs)
                Write-Debug "Started Thread $([System.Threading.Thread]::CurrentThread.ManagedThreadId)"

                # -StreamingHost (Get-Host) `
                # $host.Runspace.Debugger.SetDebugMode([System.Management.Automation.DebugModes]::RemoteScript)
                # Wait-Debugger

                $argList = $pargs.ArgumentList | ForEach-Object { "`"$_`"" } 
                & $pargs.FilePath $argList -outbuffer 64 *>&1 

                return [PSCustomObject]@{
                    ExitCode  = $LASTEXITCODE
                    IsTimeout = $false
                }
            }
            Write-Debug "Waiting on ThreadJob"
            Receive-Job -Job $job -Wait -AutoRemoveJob | & { 
                process {
                    if ($_ -is [System.Management.Automation.ErrorRecord]) {
                        "ERROR: $($_.Exception.Message)"
                    } else {
                        "$_"
                    }
                }
            }
        }
        catch {
            Write-Error ($_ | Out-String)
            return [PSCustomObject]@{
                ExitCode  = -1
                IsTimeOut = $false
            }
        }
    }
}

Export-ModuleMember -Function Invoke-Process *>&1 | Out-Null
