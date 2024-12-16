# Save this script as Get-UninstallKey.ps1
# Script to find and output the uninstall string for software
# Useful when the add/remove has been locked down or there is no entry 

# Prompt the user to enter the software name // This doesn't need to be exact
$softwareName = Read-Host -Prompt "Enter the name of the software"

# Search for the uninstall key in the registry
$uninstallKey = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" |
    Get-ItemProperty |
    Where-Object { $_.DisplayName -like "*$softwareName*" } |
    Select-Object -Property DisplayName, UninstallString, @{Name="UninstallStringFull";Expression={$_.UninstallString}}

# Output the uninstall key
$uninstallKey | Format-List
