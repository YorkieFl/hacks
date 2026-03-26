#############################################################
# CONFIGURATION - INSERT YOUR APP REGISTRATION DETAILS HERE #
#############################################################

#  Create an app registration with 
#  Microsoft Graph > Application permissions:
#  Chat.ReadBasic.All
#  Chat.Read.All
#  Grant Admin Consent

$TenantId     = "TENANTID HERE"
$ClientId     = "CLIENT ID HERE"
$ClientSecret = "SUPER SPECIAL SECRET HERE"

# Output CSV path
$OutputCsv = ".\TeamsChatExport.csv"

#############################################################
# FUNCTION: Throttling-safe Graph call with retry/backoff
#############################################################

function Invoke-GraphRequest {
    param(
        [string]$Url,
        [hashtable]$Headers,
        [string]$Method = "GET"
    )

    $MaxRetries = 10
    $Retry = 0

    while ($Retry -lt $MaxRetries) {
        try {
            return Invoke-RestMethod -Method $Method -Uri $Url -Headers $Headers
        }
        catch {
            $Response = $_.Exception.Response
            if ($Response -and $Response.StatusCode.value__ -eq 429) {
                $RetryAfter = $Response.Headers["Retry-After"]

                if ($RetryAfter) {
                    Write-Host "Rate limited. Waiting $RetryAfter seconds..."
                    Start-Sleep -Seconds $RetryAfter
                }
                else {
                    $Delay = [math]::Min([math]::Pow(2, $Retry), 60)
                    Write-Host "Rate limited. Waiting $Delay seconds..."
                    Start-Sleep -Seconds $Delay
                }

                $Retry++
            }
            else {
                throw $_
            }
        }
    }

    throw "Request failed after $MaxRetries retries due to Graph throttling."
}

#############################################################
# AUTHENTICATION
#############################################################

$TokenBody = @{
    grant_type    = "client_credentials"
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "https://graph.microsoft.com/.default"
}

$TokenResponse = Invoke-RestMethod -Method POST `
    -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
    -Body $TokenBody

$AccessToken = $TokenResponse.access_token
$Headers = @{ Authorization = "Bearer $AccessToken" }

#############################################################
# STEP 1 — Ask for User
#############################################################

$UserUPN = Read-Host "Enter user's UPN (e.g. john@contoso.com)"

#############################################################
# STEP 2 — Get All Chats for User
#############################################################

Write-Host "`nRetrieving chats for $UserUPN ...`n"

$ChatUrl = "https://graph.microsoft.com/v1.0/users/$UserUPN/chats"
$Chats = Invoke-GraphRequest -Url $ChatUrl -Headers $Headers

if (-not $Chats.value) {
    Write-Host "No chats found for this user."
    exit
}

Write-Host "Select the chat to export:`n"

# Display menu
$ChatTable = $Chats.value | Select-Object `
    @{n="Index"; e={[array]::IndexOf($Chats.value, $_)}},
    id,
    topic,
    chatType

$ChatTable | Format-Table -AutoSize

$Selection = Read-Host "Enter the Index number"
$SelectedChat = $Chats.value[$Selection]

if (-not $SelectedChat) {
    Write-Host "Invalid selection. Exiting."
    exit
}

$ChatId = $SelectedChat.id
Write-Host "`nSelected Chat ID: $ChatId"
Write-Host "Retrieving messages...`n"

#############################################################
# STEP 3 — Retrieve All Chat Messages (Paged)
#############################################################

$Messages = @()
$NextUrl = "https://graph.microsoft.com/v1.0/chats/$ChatId/messages"

# We'll collect count first to calculate rough progress
Write-Host "Fetching total message count (this may take a moment)..."

# MESSAGE COUNT TRICK:
# There is no direct count endpoint for chat messages, but we can use ?$count=true
$CountResponse = Invoke-GraphRequest -Url "$NextUrl`?$count=true&`$top=1" -Headers $Headers
$Total = $CountResponse.'@odata.count'

if (-not $Total) { $Total = 99999 } # fallback if Graph doesn't return count

Write-Host "Approximate total messages: $Total`n"

$Current = 0

while ($NextUrl) {
    $Response = Invoke-GraphRequest -Url $NextUrl -Headers $Headers

    foreach ($msg in $Response.value) {
        $Messages += $msg
        $Current++

        # Update progress bar
        $Percent = [math]::Min(($Current / $Total) * 100, 100)
        Write-Progress -Activity "Exporting chat messages" -Status "$Current / $Total" -PercentComplete $Percent
    }

    if ($Response.'@odata.nextLink') {
        $NextUrl = $Response.'@odata.nextLink'
    } else {
        $NextUrl = $null
    }
}

#############################################################
# STEP 4 — Clean & Export to CSV
#############################################################

Write-Host "`nPreparing export..."

$Export = $Messages | ForEach-Object {
    [PSCustomObject]@{
        Timestamp   = $_.createdDateTime
        From        = $_.from.user.displayName
        FromUPN     = $_.from.user.id
        MessageType = $_.messageType
        Message     = ($_.body.content -replace '<[^>]+>', '') # strip HTML
    }
}

$Export | Export-Csv -Path $OutputCsv -Encoding UTF8 -NoTypeInformation

Write-Host "`n✅ Export complete!"
Write-Host "Saved to: $OutputCsv`n"
