#  V1.0
#  A Script that queries the IIS Logs in the default location
#  then parses the IP / Account Name and Number of times it has
#  been logged
#
#  It will also show the first time it was seen and the last 
#  though this might be skewed if you clear logs
#
#  It will cross reference these IIS Logs with the 
#  account lockout logs in Event Viewer from the last hour to try and match
#  IP > Account though it seems a bit iffy
#
#  It will also show where it is working 
#  as it can be slow if there are a lot of logs


$VerbosePreference = "Continue"

Write-Verbose "Starting script..."

$logPath = "C:\inetpub\logs\LogFiles\W3SVC1\"
$loginPath = "/RDWeb/Pages/en-US/login.aspx"

Write-Verbose "Searching for IIS log files in $logPath..."

$loginAttempts = @()

Get-ChildItem -Path $logPath -Recurse -Filter *.log | ForEach-Object {
    Write-Verbose "Processing log file: $($_.FullName)"
    $lines = Get-Content $_.FullName

    $fieldLine = $lines | Where-Object { $_ -like "#Fields:*" } | Select-Object -Last 1
    if (-not $fieldLine) {
        Write-Verbose "No field header found in $($_.FullName), skipping..."
        return
    }

    $fields = $fieldLine -replace "#Fields: ", "" -split ' '
    $fieldMap = @{}
    for ($i = 0; $i -lt $fields.Length; $i++) {
        $fieldMap[$fields[$i]] = $i
    }

    if (-not ($fieldMap.ContainsKey("date") -and $fieldMap.ContainsKey("time") -and $fieldMap.ContainsKey("c-ip") -and $fieldMap.ContainsKey("cs-uri-stem"))) {
        Write-Verbose "Required fields not found in $($_.FullName), skipping..."
        return
    }

    $lines | Where-Object { $_ -notmatch "^#" -and $_ -match $loginPath } | ForEach-Object {
        $parts = $_ -split ' '
        try {
            $dateTime = [datetime]::ParseExact("$($parts[$fieldMap["date"]]) $($parts[$fieldMap["time"]])", "yyyy-MM-dd HH:mm:ss", $null)
            $loginAttempts += [PSCustomObject]@{
                DateTime = $dateTime
                IPAddress = $parts[$fieldMap["c-ip"]]
                UriStem = $parts[$fieldMap["cs-uri-stem"]]
            }
        } catch {
            Write-Verbose "Failed to parse line: $_"
        }
    }
}

Write-Verbose "Found $($loginAttempts.Count) login attempts."

# Step 2: Query Security log for Event ID 4625 from the last hour
$startTime = (Get-Date).AddHours(-1)
Write-Verbose "Querying Security log for failed logons since $startTime..."

$failedLogons = @()
try {
    $events = Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        Id = 4625
        StartTime = $startTime
    }

    Write-Verbose "Found $($events.Count) failed logon events."

    foreach ($event in $events) {
        $xml = [xml]$event.ToXml()
        $failedLogons += [PSCustomObject]@{
            TimeCreated = $event.TimeCreated
            AccountName = $xml.Event.EventData.Data | Where-Object { $_.Name -eq "TargetUserName" } | Select-Object -ExpandProperty '#text'
            IPAddress = $xml.Event.EventData.Data | Where-Object { $_.Name -eq "IpAddress" } | Select-Object -ExpandProperty '#text'
        }
    }
} catch {
    Write-Verbose "Error retrieving or parsing event logs: $_"
}

# Step 3: Cross-reference
Write-Verbose "Cross-referencing login attempts with failed logons..."

$results = @()
foreach ($attempt in $loginAttempts) {
    $match = $failedLogons | Where-Object {
        $_.IPAddress -eq $attempt.IPAddress -and
        ($_.TimeCreated - $attempt.DateTime).TotalMinutes -lt 2
    }

    $results += [PSCustomObject]@{
        AttemptTime = $attempt.DateTime
        IPAddress = $attempt.IPAddress
        AccountName = if ($match) { $match.AccountName } else { "Not Found" }
    }
}

# Step 4: Group and summarize
$summary = $results | Group-Object IPAddress, AccountName | ForEach-Object {
    [PSCustomObject]@{
        IPAddress    = $_.Group[0].IPAddress
        AccountName  = $_.Group[0].AccountName
        Count        = $_.Count
        FirstSeen    = ($_.Group | Sort-Object AttemptTime | Select-Object -First 1).AttemptTime
        LastSeen     = ($_.Group | Sort-Object AttemptTime -Descending | Select-Object -First 1).AttemptTime
    }
}

Write-Verbose "Summary complete. Found $($summary.Count) unique entries."

# Output summary
$summary | Sort-Object Count -Descending | Format-Table -AutoSize
