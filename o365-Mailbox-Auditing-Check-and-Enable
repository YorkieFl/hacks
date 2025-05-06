# A script that checks for mailboxes that do not have auditing enabled 
# that allows you to parse through them and enable auditing one by one
# ~~YorkieFL~~2025
# You will need to connect to MSOnline to run this
# a bit unwieldy if you have a lot of mailboxes 

# Get all mailboxes with auditing disabled
$mailboxes = Get-Mailbox | Where-Object {$_.AuditEnabled -eq $false}

foreach ($mailbox in $mailboxes) {
    # Display the mailbox identity and ask if auditing should be enabled
    $response = Read-Host "Do you want to enable auditing for $($mailbox.UserPrincipalName)? (y/n)"
    
    if ($response -eq 'y') {
        # Enable auditing for the mailbox
        Set-Mailbox -Identity $mailbox.Identity -AuditEnabled $true
        Write-Host "Auditing enabled for $($mailbox.UserPrincipalName)"
    } else {
        Write-Host "Auditing not enabled for $($mailbox.UserPrincipalName)"
    }
}
