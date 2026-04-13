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
    --filters Name=instance-state-name,Values=running `
    --output json

$data = $json | ConvertFrom-Json

$instances = @()

foreach ($res in $data.Reservations) {
    foreach ($inst in $res.Instances) {

        if ($inst.Platform -eq "windows") {
            continue
        }

        $name = ($inst.Tags | Where-Object { $_.Key -eq "Name" }).Value
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

[int]$num = 0

if (-not [int]::TryParse($choice, [ref]$num) -or $num -lt 1 -or $num -gt $instances.Count) {
    Write-Host "Invalid selection"
    exit 1
}

$INSTANCE_ID   = $instances[$num - 1].Id
$INSTANCE_NAME = $instances[$num - 1].Name

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

$OS_RESULT = ssm_run '". /etc/os-release; echo $ID"'

if ($OS_RESULT -match "ubuntu") {
    $TARGET_USER = "ubuntu"
} else {
    $TARGET_USER = "ec2-user"
}

# ----------------------------
# PROMPT COLOR (FULL LINE)
# ----------------------------
if ($PROFILE -eq "prod") {
    $RC_CONTENT = "export PS1='\[\033[0;31m\][$PROFILE][$INSTANCE_NAME][\u@\h \W]\\$ \[\033[0m\]'"
} else {
    $RC_CONTENT = "export PS1='\[\033[0;32m\][$PROFILE][$INSTANCE_NAME][\u@\h \W]\\$ \[\033[0m\]'"
}

$bytes = [System.Text.Encoding]::UTF8.GetBytes($RC_CONTENT)
$B64   = [Convert]::ToBase64String($bytes)

# ----------------------------
# CONFIGURE PROMPT (ROBUST)
# ----------------------------
Write-Host "Configuring prompt..."

$FIX_SCRIPT = @"
#!/bin/bash

# Ubuntu detection
if [ -f /etc/bash.bashrc ]; then

  sed -i "/^export PS1/d" /etc/bash.bashrc
  sed -i "/SSM_PROMPT_INJECTED/d" /etc/bash.bashrc
  sed -i "/^if ! \[ -n \"\${SUDO_USER}\"/,/^fi/s/^/#DISABLED /g" /etc/bash.bashrc

  sed -i "/SSM_PROMPT_INJECTED/d" /home/$TARGET_USER/.bashrc
  sed -i "/^export PS1/d" /home/$TARGET_USER/.bashrc
  sed -i "s/^PS1=/#DISABLED PS1=/g" /home/$TARGET_USER/.bashrc

  sed -i "/SSM_PROMPT_INJECTED/d" /root/.bashrc
  sed -i "/^export PS1/d" /root/.bashrc
  sed -i "s/^PS1=/#DISABLED PS1=/g" /root/.bashrc

else

  sed -i "/^export PS1/d" /home/$TARGET_USER/.bashrc 2>/dev/null || true

fi

# Apply prompt globally
echo $B64 | base64 -d > /etc/profile.d/ssm_prompt.sh
chmod +x /etc/profile.d/ssm_prompt.sh

# Ensure last override
for f in /home/$TARGET_USER/.bashrc /root/.bashrc; do
  echo "" >> \$f
  echo "# SSM_PROMPT_INJECTED" >> \$f
  echo $B64 | base64 -d >> \$f
done
"@

$fixBytes = [System.Text.Encoding]::UTF8.GetBytes($FIX_SCRIPT)
$FIX_B64  = [Convert]::ToBase64String($fixBytes)

ssm_run "`"echo $FIX_B64 | base64 -d | bash`"" | Out-Null

# ----------------------------
# CONNECT
# ----------------------------
Write-Host "Connecting as $TARGET_USER..."

$cmd = "sudo su - $TARGET_USER"
$param = "command=[""$cmd""]"

aws ssm start-session `
  --target $INSTANCE_ID `
  --profile $PROFILE `
  --region $region `
  --document-name AWS-StartInteractiveCommand `
  --parameters $param