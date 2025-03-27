$results = @()
$totalMaxVHDSize = 0
$totalCurrentVHDSize = 0

Get-VM | ForEach-Object {
  $vm = $_
  Get-VMHardDiskDrive -VMName $vm.Name | ForEach-Object {
    $vhd = Get-VHD $_.Path
    if ($vhd.FileSize -lt $vhd.Size) {
      $vhdType = 'Dynamically Expanding'
    } else {
      $vhdType = 'Fixed'
    }
    $currentVHDSizeGB = [Math]::Round($vhd.FileSize/1GB, 2)
    $maxVHDSizeGB = [Math]::Round($vhd.Size/1GB, 2)
    
    $totalCurrentVHDSize += $currentVHDSizeGB
    $totalMaxVHDSize += $maxVHDSizeGB
    
    $results += New-Object PSObject -Property @{
      "Virtual Machine" = $vm.Name
      "VHD Name" = $vhd.Path
      "VHD Size (GB)" = $currentVHDSizeGB
      "Max VHD Size (GB)" = $maxVHDSizeGB
      "VHD Type" = $vhdType
    }
  }
}

$results += New-Object PSObject -Property @{
  "Virtual Machine" = "Total"
  "VHD Name" = ""
  "VHD Size (GB)" = $totalCurrentVHDSize
  "Max VHD Size (GB)" = $totalMaxVHDSize
  "VHD Type" = ""
}

$results | Format-Table
