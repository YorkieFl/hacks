# Save this script as Get-UninstallKey.ps1
# Script to find and output the uninstall string for software
# Useful when the add/remove has been locked down or there is no entry 
# Run the XXX.ps1 -appname "APPNAME"

param (
    [string]$appName
)

$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

foreach ($path in $registryPaths) {
    $key = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$appName*" }
    if ($key) {
        Write-Output "Uninstall string for $($key.DisplayName): $($key.UninstallString)"
    }
}
