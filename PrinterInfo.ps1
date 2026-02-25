<#
.SYNOPSIS
Outputs printers and their IPs on the local machine.

.NOTES
- Works on Windows 8/Server 2012 and later (PrintManagement module).
- For Standard TCP/IP ports, the IP comes from PrinterHostAddress.
- WSD or local ports typically don't expose a direct IP; those are marked accordingly.
#>

# Get all printers and their associated ports in one go
$printers = Get-Printer -ErrorAction SilentlyContinue
$ports    = Get-PrinterPort -ErrorAction SilentlyContinue | Group-Object -Property Name -AsHashTable -AsString

# Build output objects
$result = foreach ($p in $printers) {
    $port = $ports[$p.PortName]

    # Determine IP/host details depending on port type
    $ip = $null
    $protocol = $null

    if ($port) {
        $protocol = if ($port.PrinterHostAddress) {
            # Standard TCP/IP port
            'TCP/IP'
        } elseif ($port.Name -like 'WSD-*') {
            'WSD'
        } elseif ($port.Name -like 'USB*' -or $port.Name -like 'COM*' -or $port.Name -like 'LPT*' -or $port.PortMonitor -like '*Local*') {
            'Local'
        } else {
            $port.PortMonitor
        }

        # For TCP/IP ports, pull the IP/hostname; for others, leave blank or annotate
        if ($protocol -eq 'TCP/IP') {
            $ip = $port.PrinterHostAddress
        } elseif ($protocol -eq 'WSD') {
            $ip = '(WSD – no fixed IP exposed)'
        } elseif ($protocol -eq 'Local') {
            $ip = '(Local device – no IP)'
        }
    }

    [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        PrinterName  = $p.Name
        DriverName   = $p.DriverName
        PortName     = $p.PortName
        Protocol     = $protocol
        IPAddress    = $ip
        Shared       = $p.Shared
        Default      = $p.Default
        Status       = $p.PrinterStatus
    }
}

# Output as a readable table; pipe to Export-Csv if you want a file
$result | Sort-Object PrinterName | Format-Table -AutoSize
