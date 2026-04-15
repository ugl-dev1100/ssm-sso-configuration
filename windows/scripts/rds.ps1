param(
    [string]$ENV
)

# -----------------------------
# VALIDATION
# -----------------------------
if (-not $ENV) {
    Write-Host "Usage: rds <uat|prod>"
    exit 1
}

# Use consistent profile variable
$AWS_PROFILE_NAME = $ENV
$MAP_FILE = "$env:USERPROFILE\.rds-map"

if (-not (Test-Path $MAP_FILE)) {
    Write-Host "[ERROR] Map file not found: $MAP_FILE"
    exit 1
}

# -----------------------------
# REGION
# -----------------------------
$REGION = aws configure get region --profile $AWS_PROFILE_NAME 2>$null
if (-not $REGION -or $REGION -eq "") {
    $REGION = "us-east-1"
}

Write-Host "Using region: $REGION"

# -----------------------------
# LOGIN (SSO)
# -----------------------------
if (Get-Command aws-login -ErrorAction SilentlyContinue) {
    Write-Host "Checking SSO for $AWS_PROFILE_NAME..."
    aws-login $AWS_PROFILE_NAME
}

# -----------------------------
# FIND JUMPHOST (SAFE)
# -----------------------------
$JUMP = aws ec2 describe-instances `
  --profile $AWS_PROFILE_NAME `
  --region $REGION `
  --filters "Name=instance-state-name,Values=running" `
  --query "Reservations[].Instances[?contains(join('', Tags[?Key=='Name'].Value), 'Jumphost')].InstanceId" `
  --output text

# PowerShell-safe equivalent of `head -n 1`
$JUMP = ($JUMP -split "`n" | Where-Object { $_ -ne "" } | Select-Object -First 1)

if (-not $JUMP) {
    Write-Host "[ERROR] No Jumphost found"
    exit 1
}

Write-Host "Using Jumphost: $JUMP"
Write-Host "Starting DB tunnels ($AWS_PROFILE_NAME)..."

# -----------------------------
# FETCH RDS ENDPOINTS
# -----------------------------
$rdsData = aws rds describe-db-instances `
    --profile $AWS_PROFILE_NAME `
    --region $REGION `
    --output json | ConvertFrom-Json

$rdsMap = @{}
foreach ($db in $rdsData.DBInstances) {
    $rdsMap[$db.DBInstanceIdentifier] = $db.Endpoint.Address
}

# -----------------------------
# FUNCTION
# -----------------------------
function Start-Tunnel {
    param (
        [string]$DB,
        [string]$PORT,
        [string]$ENDPOINT
    )

    if (-not $ENDPOINT) {
        Write-Host "[WARN] Endpoint not found for $DB"
        return
    }

    Write-Host "[INFO] Starting: $DB -> 127.0.0.1:$PORT"

    $arguments = @(
        "ssm", "start-session",
        "--target", $JUMP,
        "--profile", $AWS_PROFILE_NAME,
        "--region", $REGION,
        "--document-name", "AWS-StartPortForwardingSessionToRemoteHost",
        "--parameters", "host=$ENDPOINT,portNumber=3306,localPortNumber=$PORT"
    )

    Start-Process -FilePath "aws" `
        -ArgumentList $arguments `
        -WindowStyle Hidden
}

# -----------------------------
# PROCESS MAP FILE
# -----------------------------
$CURRENT_ENV = ""

Get-Content $MAP_FILE | ForEach-Object {

    $line = $_.Trim()

    if (-not $line) { return }

    if ($line -eq "[uat_databases]") { $CURRENT_ENV = "uat"; return }
    if ($line -eq "[prod_databases]") { $CURRENT_ENV = "prod"; return }

    if ($line.StartsWith("#")) { return }
    if ($CURRENT_ENV -ne $ENV) { return }

    $parts = $line.Split("=")
    if ($parts.Count -ne 2) { return }

    $DB = $parts[0].Trim()
    $PORT = $parts[1].Trim()

    $ENDPOINT = $rdsMap[$DB]

    Start-Tunnel -DB $DB -PORT $PORT -ENDPOINT $ENDPOINT
}

Write-Host "Tunnels started"