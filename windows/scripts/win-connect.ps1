param(
    [string]$PROFILE
)

if (-not $PROFILE) {
    Write-Host "Usage: win-connect <uat|prod>"
    exit 1
}

# ----------------------------
# REGION
# ----------------------------
$region = aws configure get region --profile $PROFILE 2>$null
if (-not $region) { $region = "us-east-1" }

# ----------------------------
# SSO LOGIN
# ----------------------------
aws-login $PROFILE

# ----------------------------
# FETCH INSTANCES (LINUX ONLY)
# ----------------------------
Write-Host "Fetching instances..."

$json = aws ec2 describe-instances `
    --profile $PROFILE `
    --region $region `
    --filters `
        Name=instance-state-name,Values=running `
        Name=platform,Values= `
    --output json

$data = $json | ConvertFrom-Json

$instances = @()

foreach ($res in $data.Reservations) {
    foreach ($inst in $res.Instances) {
        $name = ($inst.Tags | Where-Object {$_.Key -eq "Name"}).Value
        if (-not $name) { $name = "No-Name" }

        $instances += [PSCustomObject]@{
            Name = $name
            Id   = $inst.InstanceId
        }
    }
}

if ($instances.Count -eq 0) {
    Write-Host "No running instances found"
    exit 1
}

# ----------------------------
# DISPLAY
# ----------------------------
"{0,-4} {1,-40} {2,-22}" -f "No","Instance Name","Instance ID"

$i = 1
foreach ($inst in $instances) {
    "{0,-4} {1,-40} {2,-22}" -f $i,$inst.Name,$inst.Id
    $i++
}

# ----------------------------
# SELECT INSTANCE
# ----------------------------
Write-Host ""
$choice = Read-Host "Select instance number"

if (-not ($choice -as [int]) -or $choice -lt 1 -or $choice -gt $instances.Count) {
    Write-Host "Invalid selection"
    exit 1
}

$INSTANCE_ID = $instances[$choice - 1].Id
$INSTANCE_NAME = $instances[$choice - 1].Name

# ----------------------------
# SSM RUN FUNCTION
# ----------------------------
function ssm_run($cmd) {

    $cmd_id = aws ssm send-command `
        --instance-ids $INSTANCE_ID `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=[$cmd]" `
        --query "Command.CommandId" `
        --output text `
        --profile $PROFILE `
        --region $region

    $status = "InProgress"

    while ($status -eq "InProgress" -or $status -eq "Pending") {
        Start-Sleep -Seconds 1

        $status = aws ssm get-command-invocation `
            --command-id $cmd_id `
            --instance-id $INSTANCE_ID `
            --query "Status" `
            --output text `
            --profile $PROFILE `
            --region $region 2>$null

        if (-not $status) { $status = "Pending" }
    }

    aws ssm get-command-invocation `
        --command-id $cmd_id `
        --instance-id $INSTANCE_ID `
        --query "StandardOutputContent" `
        --output text `
        --profile $PROFILE `
        --region $region
}

# ----------------------------
# DETECT OS
# ----------------------------
Write-Host "Detecting instance OS..."

# FIXED HERE (&& → ;)
$OS_RESULT = ssm_run '". /etc/os-release; echo $ID"'

if ($OS_RESULT -match "ubuntu") {
    $TARGET_USER = "ubuntu"
    $IS_UBUNTU = $true
} else {
    $TARGET_USER = "ec2-user"
    $IS_UBUNTU = $false
}

# ----------------------------
# COLORS
# ----------------------------
if ($PROFILE -eq "prod") {
    $ENV_COLOR = "1;31"
    $HOST_COLOR = "1;33"
    $EMOJI = "RED"
    $TAB_EMOJI = "PROD"
} else {
    $ENV_COLOR = "1;32"
    $HOST_COLOR = "1;36"
    $EMOJI = "GREEN"
    $TAB_EMOJI = "UAT"
}

# ----------------------------
# BUILD PROMPT
# ----------------------------
$RC_CONTENT = "export PS1=`"`[\e]0;$TAB_EMOJI [$PROFILE] $INSTANCE_NAME\a`][\e[$ENV_COLOR" + "m]$EMOJI [$PROFILE][$INSTANCE_NAME][\e[0m] [\e[$HOST_COLOR" + "m][\u@\h \W]\\$ [\e[0m]`""

$bytes = [System.Text.Encoding]::UTF8.GetBytes($RC_CONTENT)
$B64 = [Convert]::ToBase64String($bytes)

# ----------------------------
# CONFIGURE PROMPT
# ----------------------------
Write-Host "Configuring prompt..."

if ($IS_UBUNTU) {

$FIX_SCRIPT = @"
#!/bin/bash

sed -i "/^export PS1/d" /etc/bash.bashrc
sed -i "/SSM_PROMPT_INJECTED/d" /etc/bash.bashrc

sed -i "/SSM_PROMPT_INJECTED/d" /home/ubuntu/.bashrc
sed -i "/^export PS1/d" /home/ubuntu/.bashrc

echo $B64 | base64 -d > /etc/profile.d/ssm_prompt.sh
chmod +x /etc/profile.d/ssm_prompt.sh

for f in /home/ubuntu/.bashrc /root/.bashrc; do
  echo "# SSM_PROMPT_INJECTED" >> \$f
  echo $B64 | base64 -d >> \$f
done
"@

    $fixBytes = [System.Text.Encoding]::UTF8.GetBytes($FIX_SCRIPT)
    $FIX_B64 = [Convert]::ToBase64String($fixBytes)

    ssm_run "`"echo $FIX_B64 | base64 -d | bash`"" | Out-Null

} else {

    ssm_run "`"echo $B64 | base64 -d > /etc/profile.d/ssm_prompt.sh && chmod +x /etc/profile.d/ssm_prompt.sh`"" | Out-Null
}

# ----------------------------
# CONNECT
# ----------------------------
Write-Host "Connecting as $TARGET_USER..."

aws ssm start-session `
  --target $INSTANCE_ID `
  --profile $PROFILE `
  --region $region `
  --document-name AWS-StartInteractiveCommand `
  --parameters "command=[\"sudo -u $TARGET_USER -i\"]"