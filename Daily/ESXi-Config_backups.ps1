# vSphere Config Backups - Justin Dunn 2021
#
# PLEASE READ ALL OF THIS BEFORE USING THE SCRIPT
#
# DISCLAIMER
# THE SCRIPT SOFTWARE IS PROVIDED "AS IS." Justin Dunn MAKES NO WARRANTIES OF ANY KIND WHATSOEVER WITH RESPECT TO SCRIPT SOFTWARE 
# WHICH MAY CONTAIN THIRD PARTY COMMERCIAL SOFTWARE. ALL EXPRESS OR IMPLIED CONDITIONS, REPRESENTATIONS AND WARRANTIES, 
# INCLUDING ANY WARRANTY OF NON-INFRINGEMENT OR WARRANTY OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE, ARE HEREBY 
# DISCLAIMED AND EXCLUDED TO THE EXTENT ALLOWED BY APPLICABLE LAW. USE AT OWN RISK!!
#
# Backups important configurations to a local or network location as well as emailing a report on what is in 
# those locations that was backed up. It will also report any disconnected or not responding hosts as well
# Uncomment the email function below to enable once email configuration is configured.
# 
# !!IMPORTANT You will need to create the config and archive directories ahead of time. 
# Recommended to set to a scheduled task to run once daily or as often as needed.
#
# The files / folders in the current backup directory will be moved to the Archive directory by the 
# ArchiveExisting Function, and any files older than the days configured below will be removed.
# It is set to 7 days by default.
#
#
# You can store your credentials in the Powercli Credentials Store ahead of time for scheduled scripts
# New-VICredentialStoreItem -Host 192.168.1.1 -User "Administrator@vsphere.local" -Password "password"
#
# You may need to configure accpeting Invalid certificates for your vcenter using the command
# Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
#
# You will also need to configure your execution policy as needed as well.
#
#
# This script was compiled with help from sources such as:
# https://altaro.com/vmware/powercli-distributed-switches/
# https://www.pragmaticio.com/2014/12/29/auto-esxi-host-configuration-backups/
# https://www.sharepointdiary.com/2015/06/send-mailmessage-powershell-body-html-format.html
# https://blogs.vmware.com/PowerCLI/2011/11/have-you-seen-powerclis-credential-store-feature.html


$days_to_keep_host_configs = (Get-Date).AddDays(-7)
$days_to_keep_vds_configs = (Get-Date).AddDays(-7)
$host_config_savedir = "c:\1\Backups\ESXiHosts\Current"
$host_config_archivedir = "c:\1\Backups\ESXiHosts\Archive"
$host_vds_config_savedir = "c:\1\Backups\ESXi_VDS_Switches\Current"
$host_vds_config_archivedir = "c:\1\Backups\ESXi_VDS_Switches\Archive"
$datetime = (Get-Date -f "MM_dd_yy-HH_mm")
$vcserver = "vcenter_ip_or_fqdn"

#Connect to vCenter Instance
Connect-VIServer $vcserver


Function RemoveOldBackups {
	#Find old config folders
	$old_host_configs =  Get-ChildItem -Path $host_config_archivedir -Directory -Force | Where-Object {$_.CreationTime -lt $days_to_keep_host_configs} | Select-Object -ExpandProperty FullName
	$old_vds_configs =  Get-ChildItem -Path $host_vds_config_archivedir -Directory -Force | Where-Object {$_.CreationTime -lt $days_to_keep_vds_configs} | Select-Object -ExpandProperty FullName

	#Remove them
	if ($null -ne $old_host_configs){
	$old_host_configs | Remove-Item -Force -Recurse -Confirm:$false}
	if ($null -ne $old_vds_configs){
	$old_vds_configs | Remove-Item -Force -Recurse -Confirm:$false}
	}

Function ArchiveExisting {
	$host_backup_folder_name = Get-ChildItem -Path $host_config_savedir -Directory -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
	$vds_backup_folder_name = Get-ChildItem -Path $host_vds_config_savedir -Directory -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
	Move-Item $host_backup_folder_name $host_config_archivedir
	Move-Item $vds_backup_folder_name $host_vds_config_archivedir
}
 
Function HostConfigBackup {
	$backup_time = Get-Date -f MM_dd_yy_HH_mm
	New-Item -Path $host_config_savedir -Name $backup_time -ItemType "Directory" -Force
	$DestinationDir = $host_config_savedir + "\" + $backup_time
	Get-VMHost | Where-Object{$_.ConnectionState -eq 'Connected'} | Get-VMHostFirmware -BackupConfiguration -DestinationPath $DestinationDir}



#Host Connection Status
Function HostsConnected {
	$connected_hosts = Get-VMHost | Where-Object{$_.ConnectionState -eq 'Connected'} | Select-Object Name | ConvertTo-Html | Out-String
return $connected_hosts}

Function HostsDisconnected {
$disconnected_hosts = Get-VMHost | Where-Object{$_.ConnectionState -eq 'Disconnected'} | Select-Object Name | ConvertTo-Html | Out-String
return $disconnected_hosts}

Function HostsNotResponding {
	$notresponding_hosts = Get-VMHost | Where-Object{$_.ConnectionState -eq 'NotResponding'} | Select-Object Name | ConvertTo-Html | Out-String
	return $notresponding_hosts
}

Function vDSBackup {
$vDSDetails = Get-VDSwitch
$vDSNames = $vDSDetails.Name
$backup_time = Get-Date -f MM_dd_yy_HH_mm
New-Item -Path $host_vds_config_savedir -Name $backup_time -ItemType "Directory" -Force
$vds_backup_path = $host_vds_config_savedir + "\" + $backup_time + "\"
Foreach ($vDSName in $vDSNames)
	{
	$filename= $vds_backup_path + $vDSName + "_" + $backup_time + ".zip"
	Get-VDSwitch -Name $vDSName | Export-VDSwitch -Description "vDS Backup" -Destination $filename
	}
}
 
Function RenameBackup {
	Get-ChildItem $host_config_savedir\*.tgz -Recurse|Rename-Item -NewName {$_.BaseName+"_"+($datetime)+$_.Extension}
}
 
Function EmailResults {
#HTML Template
$EmailBody = @"
 
<table style="border-collapse: collapse; border: 1px solid #0091da; width: 100%;">
<tbody>
<tr>
<td style="color: #ffffff; font-size: large; height: 35px; text-align: center; width: 645px;" colspan="2" bgcolor="#0091DA"><strong>ESXi Backup & Status Report- Daily Report on VarReportDate</strong></td>
</tr>
<tr style="border-bottom-style: solid; border-bottom-width: 1px; padding-bottom: 1px;">
<td style="width: 85px; height: 35px;"><span style="color: #ff6600;">&nbsp; <strong>Backed Up Host Configs</strong></span></td>
<td style="text-align: center; height: 35px; width: 391.609px;"><strong>VarHostBackups</strong></td>
</tr>
<tr style="height: 39px; border: 1px solid #008080;">
<td style="width: 85px; height: 39px;">&nbsp;<strong><span style="color: #ff6600;"> Backed Up vDS Configurations</span></strong></td>
<td style="text-align: center; height: 39px; width: 391.609px;"><strong>VarVDSBackups</strong></td>
</tr>
<tr style="height: 39px; border: 1px solid #008080;">
<td style="width: 85px; height: 39px;">&nbsp;<strong><span style="color: #ff6600;"> Hosts Disconnected</span></strong></td>
<td style="text-align: center; height: 39px; width: 391.609px;"><strong>VarHostsDisconnected</strong></td>
</tr>
<tr style="height: 39px; border: 1px solid #008080;">
<td style="width: 85px; height: 39px;">&nbsp;<strong><span style="color: #ff6600;"> Hosts Not Responding</span></strong></td>
<td style="text-align: center; height: 39px; width: 391.609px;"><strong>VarHostsNotResponding</strong></td>
</tr>
</tbody>
</table>
"@
 
#Get Values for report, this reports the files created in the savedir for each config type.
$HostVDSConfigsBackedUp = (Get-ChildItem $host_vds_config_savedir -File -Recurse | select-object Name, LastWriteTime | ConvertTo-Html| Out-String)
$HostConfigsBackedUp = (Get-ChildItem $host_config_savedir -File -Recurse | select-object Name, LastWriteTime | ConvertTo-Html| Out-String)
$DisconnectedHosts = HostsDisconnected
$NotRespondingHosts = HostsNotResponding
$ReportDate = (Get-Date -f "MM/dd/yy HH:mm tt")

#replace values in report body with the proper data gathered above.
$EmailBody= $EmailBody.Replace("VarReportDate",$ReportDate)
$EmailBody= $EmailBody.Replace("VarHostBackups",$HostConfigsBackedUp)
$EmailBody= $EmailBody.Replace("VarVDSBackups",$HostVDSConfigsBackedUp)
$EmailBody= $EmailBody.Replace("VarHostsDisconnected",$DisconnectedHosts)
$EmailBody= $EmailBody.Replace("VarHostsNotResponding",$NotRespondingHosts)

#Send the email
send-mailmessage -from "reports@yourdomain.com" -to "importantperson_or_DL@yourdomain.com" -subject "Daily - ESXi Host and VDS Backups" -body $EmailBody -BodyAsHtml -SmtpServer "smtp.domain.com_or_ip_omit_quotes" 
}

# You can comment out EmailResults if you do not have an SMTP server. 
RemoveOldBackups
ArchiveExisting
HostConfigBackup
RenameBackup
vDSBackup
#EmailResults
Disconnect-VIServer $VCServer -confirm:$false