#
# PS Script to check the event logs and find out the last reboot and shutdown reasons
# Should also pick up if it is a request from APC
#
#
#



# Function to get reboot and shutdown events
function Get-RebootShutdownEvents {
    $events = Get-WinEvent -LogName System | Where-Object { $_.Id -eq 1074 -or $_.Id -eq 1076 }
    return $events
}

# Function to parse event details
function Parse-Event {
    param (
        [Parameter(Mandatory=$true)]
        [System.Diagnostics.Eventing.Reader.EventLogRecord]$event
    )
    $details = [PSCustomObject]@{
        TimeGenerated = $event.TimeCreated
        SourceName = $event.ProviderName
        EventID = $event.Id
        EventType = $event.LevelDisplayName
        EventCategory = $event.TaskDisplayName
        EventDescription = $event.Properties[0].Value
        APCShutdown = $false
    }

    # Check if the shutdown was initiated by an APC UPS request
    if ($event.Properties[0].Value -like "*APC*") {
        $details.APCShutdown = $true
    }

    return $details
}

# Main script execution
$events = Get-RebootShutdownEvents
$parsedEvents = @()
foreach ($event in $events) {
    $parsedEvent = Parse-Event -event $event
    $parsedEvents += $parsedEvent
}

# Output the results in a table format
$parsedEvents | Format-Table -AutoSize
