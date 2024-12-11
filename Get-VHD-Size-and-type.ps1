$results = @()
Get-VM | ForEach-Object {
  $vm = $_
  Get-VMHardDiskDrive -VMName $vm.Name | ForEach-Object {
    $vhd = Get-VHD $_.Path
    if ($vhd.FileSize -lt $vhd.Size) {
      $vhdType = 'Dynamically Expanding'
    } else {
      $vhdType = 'Fixed'
    }
    $results += New-Object PSObject -Property @{
      "Virtual Machine" = $vm.Name
      "VHD Name" = $vhd.Path
      "VHD Size (GB)" = [Math]::Round($vhd.FileSize/1GB, 2)
      "Max VHD Size (GB)" = [Math]::Round($vhd.Size/1GB, 2)
      "VHD Type" = $vhdType
    }
  }
}
$results | Format-Table
