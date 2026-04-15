# param(
#     [string]$PROFILE
# )

# $MAP_FILE = "$env:USERPROFILE\.rds-map"

# if (-not $PROFILE) {
#     Write-Host "Usage: rds <uat|prod>"
#     exit 1
# }

# if (-not (Test-Path $MAP_FILE)) {
#     Write-Host "[ERROR] Mapping file not found (~/.rds-map)"
#     exit 1
# }

# # -----------------------------
# # REGION
# # -----------------------------
# $REGION = aws configure get region --profile $PROFILE 2>$null
# if (-not $REGION) { $REGION = "us-east-1" }

# # -----------------------------
# # LOGIN
# # -----------------------------
# aws-login $PROFILE

# # -----------------------------
# # FIND JUMPHOST
# # -----------------------------
# $JUMP = aws ec2 describe-instances `
#   --profile $PROFILE `
#   --region $REGION `
#   --filters Name=instance-state-name,Values=running `
#   --query "Reservations[].Instances[?contains(Tags[?Key=='Name'].Value | [0], 'Jumphost')].InstanceId" `
#   --output text

# $JUMP = $JUMP.Split("`n")[0]

# if (-not $JUMP) {
#     Write-Host "[ERROR] No Jumphost found"
#     exit 1
# }

# Write-Host "Using Jumphost: $JUMP"
# Write-Host "Starting DB tunnels ($PROFILE)..."

# # -----------------------------
# # FETCH ALL RDS ENDPOINTS
# # -----------------------------
# Write-Host "Fetching RDS endpoints..."

# $rdsData = aws rds describe-db-instances `
#     --profile $PROFILE `
#     --region $REGION `
#     --output json | ConvertFrom-Json

# $rdsMap = @{}
# foreach ($db in $rdsData.DBInstances) {
#     $rdsMap[$db.DBInstanceIdentifier] = $db.Endpoint.Address
# }

# $CURRENT_ENV = ""

# # -----------------------------
# # FUNCTIONS
# # -----------------------------
# function start_tunnel($DB, $PORT, $ENDPOINT) {

#     if (-not $ENDPOINT) {
#         Write-Host "[WARN] Endpoint not found for $DB"
#         return
#     }

#     Write-Host "[INFO] Starting: $DB -> 127.0.0.1:$PORT"

#     $arguments = @(
#         "ssm", "start-session",
#         "--target", $JUMP,
#         "--profile", $PROFILE,
#         "--region", $REGION,
#         "--document-name", "AWS-StartPortForwardingSessionToRemoteHost",
#         "--parameters", "host=[$ENDPOINT],portNumber=[3306],localPortNumber=[$PORT]"
#     )

#     Start-Process -FilePath "aws" `
#         -ArgumentList $arguments `
#         -WindowStyle Hidden
# }

# # -----------------------------
# # PROCESS MAP FILE
# # -----------------------------
# Get-Content $MAP_FILE | ForEach-Object {

#     $line = $_.Trim()

#     if (-not $line) { return }

#     if ($line -eq "[uat_databases]") { $CURRENT_ENV = "uat"; return }
#     if ($line -eq "[prod_databases]") { $CURRENT_ENV = "prod"; return }

#     if ($line.StartsWith("#")) { return }
#     if ($CURRENT_ENV -ne $PROFILE) { return }

#     $parts = $line.Split("=")
#     if ($parts.Count -ne 2) { return }

#     $DB = $parts[0].Trim()
#     $PORT = $parts[1].Trim()

#     $ENDPOINT = $rdsMap[$DB]

#     start_tunnel $DB $PORT $ENDPOINT
# }

# # -----------------------------
# # DONE
# # -----------------------------
# Write-Host "----------------------------------------"
# Write-Host "[OK] Tunnels started"
# Write-Host "----------------------------------------"
# Write-Host "Now verify:"
# Write-Host "Test-NetConnection -ComputerName localhost -Port PORT"

param(
    [string]$ENV
)

$MAP_FILE = "$env:USERPROFILE\.rds-map"

if (-not $ENV) {
    Write-Host "Usage: rds <uat|prod>"
    exit 1
}

# -----------------------------
# REGION
# -----------------------------
$REGION = aws configure get region --profile $ENV 2>$null
if (-not $REGION) { $REGION = "us-east-1" }

# -----------------------------
# LOGIN
# -----------------------------
if (Get-Command aws-login -ErrorAction SilentlyContinue) {
    aws-login $ENV
}

# -----------------------------
# FIND JUMPHOST
# -----------------------------
$JUMP = aws ec2 describe-instances `
  --profile $ENV `
  --region $REGION `
  --filters Name=instance-state-name,Values=running `
  --query "Reservations[].Instances[?contains(Tags[?Key=='Name'].Value | [0], 'Jumphost')].InstanceId" `
  --output text

$JUMP = $JUMP.Split("`n")[0]

if (-not $JUMP) {
    Write-Host "[ERROR] No Jumphost found"
    exit 1
}

Write-Host "Using Jumphost: $JUMP"

# -----------------------------
# FETCH RDS ENDPOINTS
# -----------------------------
$rdsData = aws rds describe-db-instances `
    --profile $ENV `
    --region $REGION `
    --output json | ConvertFrom-Json

$rdsMap = @{}
foreach ($db in $rdsData.DBInstances) {
    $rdsMap[$db.DBInstanceIdentifier] = $db.Endpoint.Address
}

$CURRENT_ENV = ""

# -----------------------------
# FUNCTION
# -----------------------------
function start_tunnel($DB, $PORT, $ENDPOINT) {

    if (-not $ENDPOINT) {
        Write-Host "[WARN] Endpoint not found for $DB"
        return
    }

    Write-Host "[INFO] Starting: $DB -> 127.0.0.1:$PORT"

    $arguments = @(
        "ssm", "start-session",
        "--target", $JUMP,
        "--profile", $ENV,
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

    start_tunnel $DB $PORT $ENDPOINT
}

Write-Host "Tunnels started"