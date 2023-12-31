###########################################################################################################
# PRE-REQUISITES
# 1) Install AWS CLI, you can run this command on PowerShell "C:\> msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi" 
# 2) Copy the "cw-agent.json" file to C:\ drive on the RDS Custom EC2 Instance
# 3) Copy the "dashboardconfig.json" file to C:\ drive on the RDS Custom EC2 Instance
# 4) Ensure the EC2 Instance Role can run aws cloudwatch put-dashboard to create the dashboard, aws ec2 describe-volumes to get volume information.
# 5) Copy this "CW_agent_config_automation.ps1" file to C:\ drive on the RDS Custom EC2 Instance
# 6) To execute the ps1 script, using PowerShell terminal run the following command & "C:\CW_agent_config_automation.ps1"
###########################################################################################################

$instanceID = Get-EC2InstanceMetadata -Category InstanceId
$imageID = Get-EC2InstanceMetadata -Category AmiId
$volumeID = aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=$instanceID Name=attachment.device,Values=xvdg --query 'Volumes[*].Attachments[*].VolumeId' --output text
$volumeLabel = aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=$instanceID Name=attachment.device,Values=xvdg --query 'Volumes[*].Tags[?Key==`Name`].Value' --output text
$region = Get-EC2InstanceMetadata -Category Region | Select-Object -ExpandProperty SystemName
$CWNamespace = "RDSCustom-" + $volumeLabel.replace('do-not-delete-rds-custom-', '').replace('-storage', '')
$dashboard = Read-Host "Enter the Name of CloudWatch Dashboard (Example - <RDS_Name>_Dashboard)"

Write-Host ""
Write-Host "============================================================================================="
Write-Host "*********************************SUMMARY OF USER INPUTS*************************************"
Write-Host "============================================================================================="
Write-Host ""
Write-Host "RDS Custom EC2 Instance ID : $instanceID"
Write-Host ""
Write-Host "RDS Custom EC2 Instance AMI ID : $imageID"
Write-Host ""
Write-Host "AWS Region Name: $region"
Write-Host ""
Write-Host "RDS Custom EC2 Instance EBS Volume ID : $volumeID"
Write-Host ""
Write-Host "RDS Custom EC2 Instance EDB Volume Name : $volumeLabel"
Write-Host ""
Write-Host "CloudWatch Dashboard Name : $dashboard"
Write-Host ""

Start-Sleep -Seconds 5

Write-Host "============================================================================================="
Write-Host "*******************************CONFIGURE CLOUDWATCH AGENT***********************************"
Write-Host "============================================================================================="
Write-Host ""

Write-Host "Begin Configuration"
Write-Host "Copying JSON Config file"
(Get-Content "C:\cw-agent.json") -replace 'RDSCustom', $CWNamespace | Set-Content "C:\cw-agent.json"
Copy-Item "C:\cw-agent.json" -Destination "C:\ProgramData\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent.json"
Write-Host "Configuration Completed"
Write-Host "Begin Restarting Cloudwatch Agent"
& "C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1" -a fetch-config -m ec2 -s -c "file:C:\ProgramData\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent.json"
Write-Host "CloudWatch Agent Restart Completed"

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "Preparing JSON Script dashboardconfig.json"
Write-Host ""

Start-Sleep -Seconds 2

(Get-Content "C:\dashboardconfig.json") -replace 'rr-rr-rr', $region -replace 'vol-zzzzzz', $volumeID -replace 'do-not-delete-rds-custom-rds-custom-2-storage', $volumeLabel -replace 'i-xxxxxx', $instanceID -replace 'ami-yyyyyy', $imageID -replace 'RDSCustom', $CWNamespace | Set-Content "C:\dashboardconfig.json"

Write-Host "Dashboard JSON Script is ready"
Write-Host ""
Write-Host "Installing the Script in Amazon CloudWatch"
Write-Host ""

aws cloudwatch put-dashboard --dashboard-name $dashboard --dashboard-body "file://C:\dashboardconfig.json" --region $region

Start-Sleep -Seconds 5

Write-Output "Installation Successful. Please log in to AWS Console and check the dashboard. The metrics might take a few minutes to populate in CloudWatch"
