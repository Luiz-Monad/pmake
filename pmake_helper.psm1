
$Script:SelfModule = "$PSScriptRoot/pmake_helper.psm1"
$Script:PowerProcessModule = "$PSScriptRoot/native/PowerProcess.dll"
$Script:ThreadJobModule = "$PSScriptRoot/native/Microsoft.PowerShell.ThreadJob.dll"

$Script:Dependencies = @(
    $Script:SelfModule, 
    $Script:ThreadJobModule, 
    $Script:PowerProcessModule)

Import-Module $Script:PowerProcessModule -Force *>&1 | Out-Null
Import-Module $Script:ThreadJobModule -Force *>&1 | Out-Null

###########################################################################################################################################

$Global:InvokeProcessTranscript = $null

function Set-ProcessTranscript {
    param (
        [string]$LogFile
    )
    $Global:InvokeProcessTranscript = $LogFile
    if (Test-Path $Global:InvokeProcessTranscript) {
        Remove-Item $Global:InvokeProcessTranscript
    }
}

Export-ModuleMember -Function Set-ProcessTranscript *>&1 | Out-Null

###########################################################################################################################################

class ProcessResult {
    $ExitCode = -1
}

function New-ProcessResult {
    param (
        [string]$LogFile
    )
    New-Object ProcessResult -Property @{ 
        ExitCode = $LASTEXITCODE
    }    
}

Export-ModuleMember -Function New-ProcessResult *>&1 | Out-Null

###########################################################################################################################################

function Write-Object {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [object]$obj,

        [Parameter(Mandatory = $false, Position = 1)]
        [Switch]$RedirectError = $false
    )
    begin {
        if ($Global:InvokeProcessTranscript) {
            $tf = [System.IO.File]::Open($Global:InvokeProcessTranscript, 
                [System.IO.FileMode]::OpenOrCreate -bor [System.IO.FileMode]::Append, 
                [System.IO.FileAccess]::Write, 
                [System.IO.FileShare]::Read)
            $tee = [System.IO.StreamWriter]::new($tf)
            $tsb = New-Object System.Text.StringBuilder
        }
        $sb = New-Object System.Text.StringBuilder
        $strm = [System.Management.Automation.Language.RedirectionStream]::Output
        $last = (Get-Date)
        $exitcode = -1
        $GLOBAL:LASTEXITCODE = $exitcode
    }
    process {
        if ($_ -is [PowerProcess.InvokeProcessFastCommand+WrapObject]) {
            $flush = ((Get-Date).Subtract($last)).TotalMilliseconds -gt 250
            if ($flush -or (($_.Stream -ne $strm) -and (-not $RedirectError))) {
                if ($sb.Length -gt 0) {
                    $sbs = $sb.ToString()
                    if ($strm -eq 'Output') { 
                        Write-Host -ForegroundColor Gray $sbs
                    }
                    elseif ($strm -eq 'Error') { 
                        Write-Host -ForegroundColor Red $sbs
                    }
                    else { 
                        Write-Host -ForegroundColor Yellow $sbs
                    }
                    if ($tee) {
                        $null = $tsb.AppendLine($sbs)
                        if ($tsb.Length -gt 65536) {
                            $null = $tee.Write($tsb.ToString())
                            $tsb = New-Object System.Text.StringBuilder
                        }
                    }                    
                    $sb = New-Object System.Text.StringBuilder
                }
                $strm = $_.Stream
            }
            elseif ($sb.Length -gt 0) {
                $null = $sb.AppendLine()
            }
            $null = $sb.Append($_.Message)
        }
        elseif ($_ -is [ProcessResult]) {
            $exitcode = $_.ExitCode
        }
        elseif (($_ -is [System.Collections.IList]) -or ($_ -is [System.Array])) {
            $_ | Write-Object -RedirectError:$RedirectError
        }
        elseif ($_ -is [System.Management.Automation.ErrorRecord]) {
            Write-Error ($_ | Out-String)
        }
        elseif ($_ -is [System.Management.Automation.DebugRecord]) {
            Write-Debug ($_ | Out-String)
        }
        elseif ($_ -is [System.Management.Automation.VerboseRecord]) {
            Write-Verbose ($_ | Out-String)
        }
        else {
            $null = $sb.AppendLine((Out-String $_))
        }
    } 
    end {
        if ($sb.Length -gt 0) {
            $sbs = $sb.ToString()
            if ($strm -eq 'Output') { 
                Write-Host -ForegroundColor Gray $sbs
            }
            elseif ($strm -eq 'Error') { 
                Write-Host -ForegroundColor Red $sbs
            }
            else { 
                Write-Host -ForegroundColor Yellow $sbs
            }
        }
        if ($tee) {
            $null = $tsb.AppendLine($sb.ToString())
            if ($tsb.Length -gt 0) {
                $null = $tee.Write($tsb.ToString())
            }
            $null = $tee.Close()
            $null = $tf.Close()
            $tee = $null
            $tf = $null
        }
        $GLOBAL:LASTEXITCODE = $exitcode
    }
}

Export-ModuleMember -Function Write-Object *>&1 | Out-Null

###########################################################################################################################################

function Invoke-ThreadJob {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false, Position = 1)]
        [hashtable]$ArgumentList = @(),
        
        [Parameter(Mandatory = $false, Position = 3)]
        [string]$Name = "",

        [Parameter(Mandatory = $false, Position = 4)]
        [TimeSpan]$Timeout = [System.TimeSpan]::FromMinutes(2)
    )
    begin {
        $pargs = @{
            Name         = $Name
            Verbose      = $VerbosePreference
            Debug        = $DebugPreference
            Modules      = $Script:Dependencies
            ScriptBlock  = $ScriptBlock
            ArgumentList = $ArgumentList
            Timeout      = $Timeout
        }
        $job = Start-ThreadJob `
            -Verbose:$VerbosePreference `
            -Debug:$DebugPreference `
            -Name $Name `
            -ArgumentList @($pargs) `
            -ScriptBlock {
            [CmdletBinding()]
            param($pargs)
            try {
                $VerbosePreference = $pargs.Verbose
                $DebugPreference = $pargs.Debug

                if ($DebugPreference -notmatch '(Ignore|SilentlyContinue)') {
                    $tid = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                    Write-Debug "Started Thread $tid : $($pargs.Name)"
                    # Wait-Debugger
                }

                foreach ($module in $pargs.Modules) {
                    Import-Module $module -Force *>&1 | Out-Null
                }

                & ($pargs.ScriptBlock) ($pargs.ArgumentList)

                if ($DebugPreference -notmatch '(Ignore|SilentlyContinue)') {
                    $tid = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                    Write-Debug "Completed Thread $tid : $($pargs.Name)"
                }

                $true
            }
            catch {
                Write-Error ($_ | Out-String)
                $false
            }
        }
    } process {
        if ($DebugPreference -notmatch '(Ignore|SilentlyContinue)') {
            Write-Debug (Get-Job | Out-String)
            Write-Debug "Waiting on ThreadJob $Name"
        }

        Receive-Job $job -Wait

    } end {
        if ($DebugPreference -notmatch '(Ignore|SilentlyContinue)') {
            Write-Debug (Get-Job | Out-String)
            Write-Debug "Removing ThreadJob $Name"
        }

        Remove-Job $job

    }
}

Export-ModuleMember -Function Invoke-ThreadJob *>&1 | Out-Null

###########################################################################################################################################

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
        [System.Diagnostics.ProcessPriorityClass]$Priority = [System.Diagnostics.ProcessPriorityClass]::Normal
    )
    begin {
        $Name = if (Test-Path $FilePath) { (Get-Item $FilePath).BaseName } else { "" }
        $pargs = @{
            Name             = $Name
            Verbose          = $VerbosePreference
            Debug            = $DebugPreference
            Modules          = $Script:Dependencies
            FilePath         = $FilePath
            ArgumentList     = $ArgumentList
            WorkingDirectory = $WorkingDirectory
            Timeout          = $Timeout
            Priority         = $Priority
        }
        Write-Debug "Execute command : $WorkingDirectory / $FilePath $ArgumentList "
        $job = Start-ThreadJob `
            -Verbose:$VerbosePreference `
            -Debug:$DebugPreference `
            -Name $Name `
            -ArgumentList @($pargs) `
            -ScriptBlock {
            [CmdletBinding()]
            param($pargs)
            try {
                $VerbosePreference = $pargs.Verbose
                $DebugPreference = $pargs.Debug

                if ($DebugPreference -notmatch '(Ignore|SilentlyContinue)') {
                    $tid = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                    Write-Debug "Started Thread $tid : $($pargs.Name)"
                    # Wait-Debugger
                }

                foreach ($module in $pargs.Modules) {
                    Import-Module $module -Force *>&1 | Out-Null
                }

                Invoke-ProcessFast `
                    -WrapOutputStream `
                    -MergeStandardErrorToOutput `
                    -OutputBuffer 1 `
                    -FilePath $pargs.FilePath `
                    -ArgumentList $pargs.ArgumentList `
                    -WorkingDirectory $pargs.WorkingDirectory `
                    -Wait *>&1

                if ($DebugPreference -notmatch '(Ignore|SilentlyContinue)') {
                    $tid = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                    Write-Debug "Completed Thread $tid : $($pargs.Name)"
                    Write-Debug "Process Exit Code: $LASTEXITCODE"
                }

                New-ProcessResult -ExitCode $LASTEXITCODE
            }
            catch {
                Write-Error ($_ | Out-String)
                New-ProcessResult -ExitCode -1
            }
        }
    } process {
        if ($DebugPreference -notmatch '(Ignore|SilentlyContinue)') {
            Write-Debug (Get-Job | Out-String)
            Write-Debug "Waiting on ProcessJob $Name"
        }

        Receive-Job $job -Wait

    } end {
        if ($DebugPreference -notmatch '(Ignore|SilentlyContinue)') {
            Write-Debug (Get-Job | Out-String)
            Write-Debug "Removing ProcessJob $Name"
        }

        Remove-Job $job

    }
}

Export-ModuleMember -Function Invoke-Process *>&1 | Out-Null

###########################################################################################################################################
