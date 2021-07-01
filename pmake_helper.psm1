
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

$Script:InvokeProcessTranscript = $null

function Set-ProcessTranscript {
    param (
        [string]$LogFile
    )
    $Script:InvokeProcessTranscript = $LogFile
}

Export-ModuleMember -Function Set-ProcessTranscript *>&1 | Out-Null

###########################################################################################################################################

function Write-Object {
    [CmdLetBinding()]
    param (
        [string]$tag, 
        [Parameter(ValueFromPipeline)][object]$obj
    )
    begin {
        $ix = 0;
    }
    process {
        $ntag = "$($tag)[$ix]:"
        if ($null -eq $obj) {
            #Write-Host ( "$($ntag)[null]" )
            return;
        }
        #Write-Host ( "$($ntag)$($obj.GetType().FullName)" )
        if (($obj -is [System.Collections.IList]) -or ($obj -is [System.Array])) {
            $obj | Write-Object -Tag $ntag
        }
        elseif ($obj -is [System.Management.Automation.ErrorRecord]) {
            Write-Host -ForegroundColor Red "ERROR: $($obj.Exception.Message)"
        }
        elseif (($obj.Stream) -and ($obj.Stream -eq 'Error')) {
            Write-Host -ForegroundColor Red "ERROR: $($obj.Message)"
        }
        elseif (($obj.Stream) -and ($obj.Stream -eq 'Output')) {
            Write-Host ( $obj.Message )
        }
        else {
            Write-Host ( $obj | Out-String )
        }
        $ix = $ix + 1
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
        [TimeSpan]$Timeout = [System.TimeSpan]::FromMinutes(2),

        [Parameter(Mandatory = $false, Position = 5)][Switch]
        [Boolean]$RedirectError = $false
    )
    begin {
        $pargs = @{
            Name          = $Name
            Verbose       = $VerbosePreference
            Debug         = $DebugPreference
            Modules       = $Script:Dependencies
            RedirectError = $RedirectError
            ScriptBlock   = $ScriptBlock
            ArgumentList  = $ArgumentList
            Timeout       = $Timeout
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
        }

        Write-Debug "Waiting on ThreadJob $Name"
        Receive-Job $job -Wait

    } end {
        if ($DebugPreference -notmatch '(Ignore|SilentlyContinue)') {
            Write-Debug (Get-Job | Out-String)
        }

        Write-Debug "Removing ThreadJob $Name"
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
        [System.Diagnostics.ProcessPriorityClass]$Priority = [System.Diagnostics.ProcessPriorityClass]::Normal,

        [Parameter(Mandatory = $false, Position = 6)][Switch]
        [Boolean]$RedirectError = $false
    )
    begin {
        $Name = if (Test-Path $FilePath) { (Get-Item $FilePath).BaseName } else { "" }
        $pargs = @{
            Name             = $Name
            Verbose          = $VerbosePreference
            Debug            = $DebugPreference
            Modules          = $Script:Dependencies
            RedirectError    = $RedirectError
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
                    -OutputBuffer 256 `
                    -FilePath $pargs.FilePath `
                    -ArgumentList $pargs.ArgumentList `
                    -WorkingDirectory $pargs.WorkingDirectory `
                    -Wait *>&1 | 
                Write-Object

                Write-Debug "Process Exit Code: $LASTEXITCODE"

                if ($DebugPreference -notmatch '(Ignore|SilentlyContinue)') {
                    $tid = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                    Write-Debug "Completed Thread $tid : $($pargs.Name)"
                }

                [PSCustomObject]@{
                    ExitCode  = $LASTEXITCODE
                    IsTimeout = $false
                }
            }
            catch {
                Write-Error ($_ | Out-String)
                return [PSCustomObject]@{
                    ExitCode  = -1
                    IsTimeout = $false
                }
            }
        }
    } process {
        if ($DebugPreference -notmatch '(Ignore|SilentlyContinue)') {
            Write-Debug (Get-Job | Out-String)
        }

        Write-Debug "Waiting on ProcessJob $Name"
        Receive-Job $job -Wait

    } end {
        if ($DebugPreference -notmatch '(Ignore|SilentlyContinue)') {
            Write-Debug (Get-Job | Out-String)
        }

        Write-Debug "Removing ProcessJob $Name"
        Remove-Job $job

    }
}

Export-ModuleMember -Function Invoke-Process *>&1 | Out-Null

###########################################################################################################################################
