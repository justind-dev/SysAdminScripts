# vSphere Config Backups - Justin Dunn
# Backups important configurations to a local or network location as well as a report on what is in 
# those locations. Can be ran once daily since the file names have MM_dd_yy although,
# you could modify the file names to include the minute and seconds if you would like 
# run more frequently, other wise you will run into duplicate filename issues.
#
# The files / folders in the current backup directory will be moved to the Archive directory by the 
# ArchiveExisting Function
#
#
# You can store your credentials in the Powercli Credentials Store ahead of time for scheduled scripts
# New-VICredentialStoreItem -Host 192.168.1.1 -User "Administrator@vsphere.local" -Password "password"
#
#
# This script was compiled with help from sources such as:
# https://www.pragmaticio.com/2014/12/29/auto-esxi-host-configuration-backups/
# https://www.sharepointdiary.com/2015/06/send-mailmessage-powershell-body-html-format.html
# https://blogs.vmware.com/PowerCLI/2011/11/have-you-seen-powerclis-credential-store-feature.html

$host_config_savedir = "c:\Configs\ESXiHosts\Current"
$host_config_archivedir = "c:\Configs\ESXiHosts\Archive"
$host_VDS_config_savedir = "c:\Configs\ESXi_VDS_Switches\Current"
$host_VDS_config_archivedir = "c:\Configs\ESXi_VDS_Switches\Archive"
$datetime = (Get-Date -f MM_dd_yy)
$VCServer = "vcenter_ip_or_fqdn"

#Connect to vCenter Instance
Connect-VIServer $VCServer
 
Function ArchiveExisting {
Move-item -path $host_config_savedir\*tgz -destination $host_config_archivedir 

Foreach ($folder in Get-ChildItem -Path $host_VDS_config_savedir -Directory){
$new_archive_path = $host_VDS_config_archivedir + "\" + $folder.Name
if (Test-Path -Path $new_archive_path) {
    Continue
} 
else {
    New-Item -Path $new_archive_path -ItemType "Directory" -Force
}
$working_path = $host_VDS_config_savedir + "\" + $folder.name
Move-item -path $working_path\*zip -destination $new_archive_path -Force
}

Get-ChildItem -Path $host_VDS_config_savedir -Directory | Remove-Item -Recurse -Force

}
 
Function HostConfigBackup {
Get-VMHost | Where-Object{$_.ConnectionState -eq 'connected'} | Get-VMHostFirmware -BackupConfiguration -DestinationPath $host_config_savedir }

Function HostsDisconnected {

    Get-VMHost | Where-Object{$_.ConnectionState -eq 'connected'} | Get-VMHostFirmware -BackupConfiguration -DestinationPath $host_config_savedir }
 
Function vDSBackup {
	$vDSDetails = Get-VDSwitch
	$vDSNames = $vDSDetails.Name
	Foreach ($vDSName in $vDSNames)
		{
		$DestiationDir = $host_VDS_config_savedir + "\" + $vDSName + "\"
		New-Item -Path $DestiationDir -ItemType "Directory" -Force
		$filename= $DestiationDir + $vDSName + "_" + $datetime + ".zip"
		Get-VDSwitch -Name $vDSName | Export-VDSwitch -Description "vDS Backup" -Destination $filename
		}
 }
 
Function RenameBackup {
Get-ChildItem $host_config_savedir\*.tgz |Rename-Item -NewName {$_.BaseName+"_"+($datetime)+$_.Extension}
}
 
Function EmailResults {
#HTML Template
$EmailBody = @"
 
<table style="border-collapse: collapse; border: 1px solid #0091da; width: 100%;">
<tbody>
<tr>
<td style="color: #ffffff; font-size: large; height: 35px; text-align: center; width: 645px;" colspan="2" bgcolor="#0091DA"><strong>ESXi Backup Report- Daily Report on VarReportDate</strong></td>
</tr>
<tr style="border-bottom-style: solid; border-bottom-width: 1px; padding-bottom: 1px;">
<td style="width: 250.391px; height: 35px;"><span style="color: #ff6600;">&nbsp; <strong>Backed Up Host Configs</strong></span></td>
<td style="text-align: center; height: 35px; width: 391.609px;"><strong>VarHostBackups</strong></td>
</tr>
<tr style="height: 39px; border: 1px solid #008080;">
<td style="width: 250.391px; height: 39px;">&nbsp;<strong><span style="color: #ff6600;"> Backed Up vDS Configurations</span></strong></td>
<td style="text-align: center; height: 39px; width: 391.609px;"><strong>VarVDSBackups</strong></td>
</tr>
</tbody>
</table>
"@
 
#Get Values for report
$HostConfigsBackedUp = (Get-ChildItem $host_config_savedir -File -Recurse | select-object Name, LastWriteTime | ConvertTo-Html | Out-String)
$HostVDSConfigsBackedUp = (Get-ChildItem $host_VDS_config_savedir -File -Recurse | select-object Name, LastWriteTime | ConvertTo-Html| Out-String)
$ReportDate = (Get-Date -f dd_MM_yy)

#replace values in report body
$EmailBody= $EmailBody.Replace("VarReportDate",$ReportDate)
$EmailBody= $EmailBody.Replace("VarHostBackups",$HostConfigsBackedUp)
$EmailBody= $EmailBody.Replace("VarVDSBackups",$HostVDSConfigsBackedUp)

#Send the email
send-mailmessage -from "from@domain.com" -to "importantperson@domain.com" -subject "Daily - ESXi Host Backups" -body $EmailBody -BodyAsHtml -SmtpServer "smtpserver_ip_omit_quotes" }
 
ArchiveExisting
HostConfigBackup
RenameBackup
vDSBackup
EmailResults
Disconnect-VIServer $VCServer -confirm:$false