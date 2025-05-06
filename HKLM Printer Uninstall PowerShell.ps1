# Define the registry path for printers
$printersRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Printers"

# Get all printer names from the registry
$printers = Get-ChildItem -Path $printersRegPath

# Loop through each printer and remove it
foreach ($printer in $printers) {
    $printerPath = Join-Path -Path $printersRegPath -ChildPath $printer.PSChildName
    Remove-Item -Path $printerPath -Recurse -Force
    Write-Output "Removed printer: $($printer.PSChildName)"
}

Write-Output "All printers have been removed from the registry."
