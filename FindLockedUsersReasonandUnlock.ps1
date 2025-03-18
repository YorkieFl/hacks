
#// This Script queries for AD Locked Users 
#// It will also query the Security Event Logs for the users
#// It will then show you the Event Log details associated with that user to help with troubleshooting *untested*
#// It will also allow you to unlock a user from the list by typing their username

Import-Module ActiveDirectory

# Get list of locked-out users
$lockedOutUsers = Search-ADAccount -LockedOut

# Display locked-out users in a table
$lockedOutUsers | Format-Table SamAccountName, Name, LastLogonDate -AutoSize

# Function to get EventID 4740 details for a user
function Get-LockoutEvent {
    param (
        [string]$username
    )
    Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        Id = 4740
    } | Where-Object {
        $_.Properties[0].Value -like "*$username*"
    } | Select-Object TimeCreated, @{Name="LockedOutUser"; Expression={$_.Properties[0].Value}}, @{Name="CallerComputerName"; Expression={$_.Properties[1].Value}}
}

# Prompt to unlock a user or exit
$unlockUser = Read-Host "Enter the username to unlock (or type 'exit' to quit)"

# Check if the user wants to exit
if ($unlockUser -ne 'exit') {
    # Get and display lockout event details
    $lockoutEvents = Get-LockoutEvent -username $unlockUser
    $lockoutEvents | Format-Table -AutoSize

    # Unlock the user
    Unlock-ADAccount -Identity $unlockUser
    Write-Host "$unlockUser has been unlocked."
} else {
    Write-Host "No account unlocked. Exiting script."
}
