<#
  author:  Zisis Lianas
 
  With no option, this PowerShell script will create to csv file with unused
  storage blobs / disks. When executing with -deleteUnused, the script
  will delete all unused storage / blobs.
#>

[cmdletbinding()]
Param([switch]$deleteUnused)


try {
    Get-AzureRmContext
}
catch {
    if ($? -eq $FALSE) {
        write-output "You are not logged in, please log in..."
        Login-AzureRmAccount
    }
}


<#
  fetch all storage blobs and check if storage blob is unlocked
#>
$sa = Get-AzureRmStorageAccount
$sblobs = $sa | Get-AzureStorageContainer | Get-AzureStorageBlob
$unlockedblobs = $sblobs | where {$_.ICloudBlob.Properties.LeaseStatus -eq "Unlocked"}

$umd = foreach ($md in $unlockedblobs) {
    $StorageAccountName = if ($md.ICloudBlob.Parent.Uri.Host -match '([a-z0-9A-Z]*)(?=\.blob\.core\.windows\.net)') {$Matches[0]}
    $StorageAccount = $sa | where { $_.StorageAccountName -eq $StorageAccountName } 
    $property = [ordered]@{
        StorageAccountName = $StorageAccountName;
        LeaseStatus = $md.ICloudBlob.Properties.LeaseStatus;
        LeaseState = $md.ICloudBlob.Properties.LeaseState;
        AbsoluteUri = $md.ICloudBlob.Uri.AbsoluteUri;
    }
    new-object -TypeName PSObject -Property $property
}
$umd | export-csv -path '.\unused_managed_disks.csv' -NoTypeInformation
if ($deleteUnused -eq $TRUE) {
    "Deleting unused managed disks."
    $unlockedblobs | Remove-AzureStorageBlob
}


<#
  check for unmanaged disks
#>
$rmdisks = Get-AzureRmDisk
$udisks = $rmdisks | where {$_.OwnerId -eq $null}
$udisks | export-csv -path '.\unused_unmanaged_disks.csv' -NoTypeInformation
if ($deleteUnused -eq $TRUE) {
    "Deleting unused storage blobs."
	$udisks | Remove-AzureRmDisk
}

