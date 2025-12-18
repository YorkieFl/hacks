# PS Script to check the event logs and find out the last reboot and shutdown reasons
# Should also pick up if it is a request from APC
# expanded results to show the full event log entry for each one that is picked up


# Function to get reboot and shutdown events
function Get-RebootShutdownEvents {
    # Filter at the source for better performance and clarity
    Get-WinEvent -FilterHashtable @{ LogName='System'; Id=@(1074,1076) } |
    Sort-Object TimeCreated -Descending
}

# Function to parse event details
function Parse-Event {
    param (
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Eventing.Reader.EventLogRecord] $event
    )
    # Use the full rendered message
    $msg = $event.Message

    [PSCustomObject]@{
        TimeGenerated   = $event.TimeCreated
        SourceName      = $event.ProviderName
        EventID         = $event.Id
        EventType       = $event.LevelDisplayName
        EventCategory   = $event.TaskDisplayName
        EventDescription= $msg
        APCShutdown     = ($msg -match 'APC')
    }
}

# Main script execution
$events = Get-RebootShutdownEvents
$parsedEvents = foreach ($event in $events) { Parse-Event -event $event }

# Output the results in a table format without truncation
# (Out-String -Width forces PowerShell to render the full text)
$parsedEvents |
    Select-Object TimeGenerated, SourceName, EventID, EventType, EventCategory, APCShutdown, EventDescription |
    Out-String -Width 4096 |
    Write-Host

# Optional: also export to CSV to preserve full text
$csvPath = Join-Path $env:USERPROFILE 'Desktop\Reboot-Shutdown-Events.csv'
$parsedEvents | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write
