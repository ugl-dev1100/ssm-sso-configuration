# param(
#     [string]$PROFILE
# )

# if (-not $PROFILE) {
#     Write-Host "Usage: win-connect <uat|prod>"
#     exit 1
# }

# # ----------------------------
# # REGION
# # ----------------------------
# $region = aws configure get region --profile $PROFILE 2>$null
# if (-not $region) { $region = "us-east-1" }

# # ----------------------------
# # SSO LOGIN
# # ----------------------------
# aws sts get-caller-identity --profile $PROFILE 2>$null | Out-Null
# if ($LASTEXITCODE -ne 0) {
#     aws sso login --profile $PROFILE
# }

# # ----------------------------
# # GET SSM CONNECTED INSTANCES
# # ----------------------------
# $ssmInstances = aws ssm describe-instance-information `
#     --profile $PROFILE `
#     --region $region `
#     --query "InstanceInformationList[].InstanceId" `
#     --output text

# $ssmSet = $ssmInstances -split "\s+"

# # ----------------------------
# # FETCH INSTANCES
# # ----------------------------
# Write-Host "Fetching instances..."

# $instances = aws ec2 describe-instances `
#   --profile $PROFILE `
#   --region $REGION `
#   --no-paginate `
#   --filters `
#     Name=instance-state-name,Values=running `
#     Name=platform-details,Values=Linux/UNIX `
#   --query "Reservations[].Instances[].{
#     Name: Tags[?Key=='Name'] | [0].Value,
#     Id: InstanceId,
#     ImageId: ImageId
#   }" `
#   --output json | ConvertFrom-Json

# # Filter Linux + SSM connected
# $instances = $instances | Where-Object {
#     $_.Platform -ne "windows" -and ($ssmSet -contains $_.Id)
# }

# if (-not $instances) {
#     Write-Host "No SSM-connected Linux instances found"
#     exit 1
# }

# # ----------------------------
# # DISPLAY
# # ----------------------------
# "{0,-4} {1,-40} {2,-22}" -f "No","Instance Name","Instance ID"

# for ($i=0; $i -lt $instances.Count; $i++) {
#     $name = $instances[$i].Name
#     if (-not $name) { $name = "No-Name" }

#     "{0,-4} {1,-40} {2,-22}" -f ($i+1), $name, $instances[$i].Id
# }

# # ----------------------------
# # SELECT INSTANCE
# # ----------------------------
# Write-Host ""
# $choice = Read-Host "Select instance number"

# $num = 0
# if (-not [int]::TryParse($choice, [ref]$num) -or $num -lt 1 -or $num -gt $instances.Count) {
#     Write-Host "Invalid selection"
#     exit 1
# }

# $inst = $instances[$num - 1]

# $INSTANCE_ID = $inst.Id
# $INSTANCE_NAME = $inst.Name
# $IMAGE_ID = $inst.ImageId

# # ----------------------------
# # FAST OS DETECTION (AMI)
# # ----------------------------
# $AMI_NAME = aws ec2 describe-images `
#     --image-ids $IMAGE_ID `
#     --region $region `
#     --query "Images[0].Name" `
#     --output text `
#     --profile $PROFILE

# if ($AMI_NAME -match "ubuntu") {
#     $TARGET_USER = "ubuntu"
# } else {
#     $TARGET_USER = "ec2-user"
# }

# # ----------------------------
# # PROMPT COLOR
# # ----------------------------
# if ($PROFILE -eq "prod") {
#     $COLOR = "0;31"
# } else {
#     $COLOR = "0;32"
# }

# $RC_CONTENT = @"
# # SSM_PROMPT_INJECTED
# unset PROMPT_COMMAND
# unset color_prompt
# unset force_color_prompt
# export PS1="\[\033[$COLOR`m\][$PROFILE][$INSTANCE_NAME][\u@\h \W]\$\[\033[0m\] "
# "@

# $B64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($RC_CONTENT))

# # ----------------------------
# # PROMPT INJECTION (ASYNC)
# # ----------------------------
# Write-Host "Configuring prompt (background)..."

# $cmd = "echo $B64 | base64 -d > /etc/profile.d/ssm_prompt.sh"

# aws ssm send-command `
#     --instance-ids $INSTANCE_ID `
#     --document-name "AWS-RunShellScript" `
#     --parameters "commands=[$cmd]" `
#     --profile $PROFILE `
#     --region $region `
#     | Out-Null

# # ----------------------------
# # CONNECT
# # ----------------------------
# Write-Host "Connecting as $TARGET_USER..."

# $param = "command=[`"sudo su - $TARGET_USER`"]"

# aws ssm start-session `
#   --target $INSTANCE_ID `
#   --profile $PROFILE `
#   --region $region `
#   --document-name AWS-StartInteractiveCommand `
#   --parameters $param
param(
    [Parameter(Mandatory)][ValidateSet("uat","prod")][string]$PROFILE
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ----------------------------
# REGION
# ----------------------------
$region = (aws configure get region --profile $PROFILE 2>$null) ?? "us-east-1"

# ----------------------------
# SSO LOGIN (lazy — only if needed)
# ----------------------------
aws sts get-caller-identity --profile $PROFILE 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { aws sso login --profile $PROFILE }

# ----------------------------
# FETCH RUNNING LINUX INSTANCES WITH SSM
# ----------------------------
Write-Host "Fetching instances..." -ForegroundColor Cyan

$ssmSet = [System.Collections.Generic.HashSet[string]](
    (aws ssm describe-instance-information `
        --profile $PROFILE --region $region `
        --query "InstanceInformationList[].InstanceId" `
        --output text) -split "\s+" | Where-Object { $_ }
)

$instances = aws ec2 describe-instances `
    --profile $PROFILE --region $region `
    --filters Name=instance-state-name,Values=running `
    --query "Reservations[].Instances[].{Name:Tags[?Key=='Name']|[0].Value, Id:InstanceId, ImageId:ImageId, Platform:Platform}" `
    --output json | ConvertFrom-Json |
    Where-Object { $_.Platform -ne "windows" -and $ssmSet.Contains($_.Id) }

if (-not $instances) {
    Write-Host "No SSM-connected Linux instances found." -ForegroundColor Yellow
    exit 1
}

# ----------------------------
# DISPLAY
# ----------------------------
Write-Host ""
"{0,-4} {1,-40} {2,-22}" -f "#", "Name", "Instance ID"
Write-Host ("-" * 68)
$i = 1
foreach ($inst in $instances) {
    "{0,-4} {1,-40} {2,-22}" -f $i, ($inst.Name ?? "No-Name"), $inst.Id
    $i++
}
Write-Host ""

# ----------------------------
# SELECT
# ----------------------------
$choice = Read-Host "Select instance number"
if (-not ($choice -match '^\d+$') -or [int]$choice -lt 1 -or [int]$choice -gt $instances.Count) {
    Write-Host "Invalid selection." -ForegroundColor Red; exit 1
}
$inst = $instances[[int]$choice - 1]

# ----------------------------
# OS DETECTION via AMI name
# ----------------------------
$amiName = aws ec2 describe-images `
    --image-ids $inst.ImageId --region $region `
    --query "Images[0].Name" --output text --profile $PROFILE

$targetUser = if ($amiName -match "ubuntu") { "ubuntu" } else { "ec2-user" }

# ----------------------------
# INJECT COLORED PROMPT
# ----------------------------
$color   = if ($PROFILE -eq "prod") { "0;31" } else { "0;32" }
$ps1     = "\[\033[${color}m\][$PROFILE][$($inst.Name ?? $inst.Id)][\u@\h \W]\$\[\033[0m\] "
$rc      = "unset PROMPT_COMMAND color_prompt force_color_prompt`nexport PS1=`"$ps1`""
$b64     = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($rc))

Write-Host "Injecting prompt..." -ForegroundColor DarkGray
aws ssm send-command `
    --instance-ids $inst.Id `
    --document-name "AWS-RunShellScript" `
    --parameters "commands=[`"echo $b64 | base64 -d > /etc/profile.d/ssm_prompt.sh`"]" `
    --profile $PROFILE --region $region | Out-Null

# ----------------------------
# CONNECT
# ----------------------------
Write-Host "Connecting as $targetUser to $($inst.Name ?? $inst.Id)..." -ForegroundColor Green
aws ssm start-session `
    --target $inst.Id `
    --profile $PROFILE --region $region `
    --document-name AWS-StartInteractiveCommand `
    --parameters "command=[`"sudo su - $targetUser`"]"