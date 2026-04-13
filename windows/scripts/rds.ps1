param(
    [string]$PROFILE
)

$MAP_FILE = "$env:USERPROFILE\.rds-map"

if (-not $PROFILE) {
    Write-Host "Usage: rds <uat|prod>"
    exit 1
}

if (-not (Test-Path $MAP_FILE)) {
    Write-Host "[ERROR] Mapping file not found (~/.rds-map)"
    exit 1
}

# -----------------------------
# REGION
# -----------------------------
$REGION = aws configure get region --profile $PROFILE 2>$null
if (-not $REGION) { $REGION = "us-east-1" }

# -----------------------------
# SSO LOGIN
# -----------------------------
aws-login $PROFILE

# -----------------------------
# FIND JUMPHOST
# -----------------------------
$JUMP = aws ec2 describe-instances `
  --profile $PROFILE `
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
Write-Host "Starting DB tunnels ($PROFILE)..."

$CURRENT_ENV = ""

# -----------------------------
# FUNCTIONS
# -----------------------------

function is_port_active($port) {
    $result = Test-NetConnection -ComputerName 127.0.0.1 -Port $port -WarningAction SilentlyContinue
    return $result.TcpTestSucceeded
}

function kill_port($port) {
    $conns = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    foreach ($c in $conns) {
        try {
            Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue
        } catch {}
    }
}

function start_tunnel($DB, $PORT, $ENDPOINT) {

    if (is_port_active $PORT) {
        Write-Host "[OK] $DB already active on $PORT"
        return
    }

    Write-Host "[INFO] Starting: $DB -> 127.0.0.1:$PORT"

    kill_port $PORT

    $cmd = "aws ssm start-session --target $JUMP --profile $PROFILE --region $REGION --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{""host"":[""$ENDPOINT""],""portNumber"":[""3306""],""localPortNumber"":[""$PORT""]}'"

    Start-Process powershell -ArgumentList @(
        "-NoProfile",
        "-Command",
        $cmd
    ) -WindowStyle Hidden

    # Wait for tunnel
    for ($i = 1; $i -le 15; $i++) {
        if (is_port_active $PORT) {
            Write-Host "[OK] Tunnel ready: $DB ($PORT)"
            return
        }
        Start-Sleep -Seconds 1
    }

    Write-Host "[WARN] Tunnel started (may take few seconds): $DB ($PORT)"
}

# -----------------------------
# PROCESS MAP FILE
# -----------------------------
Get-Content $MAP_FILE | ForEach-Object {

    $line = $_.Trim()

    if (-not $line) { return }

    if ($line -eq "[uat_databases]") {
        $CURRENT_ENV = "uat"
        return
    }

    if ($line -eq "[prod_databases]") {
        $CURRENT_ENV = "prod"
        return
    }

    if ($line.StartsWith("#")) { return }
    if ($CURRENT_ENV -ne $PROFILE) { return }

    $parts = $line.Split("=")
    if ($parts.Count -ne 2) { return }

    $DB = $parts[0].Trim()
    $PORT = $parts[1].Trim()

    # -----------------------------
    # GET ENDPOINT
    # -----------------------------
    $ENDPOINT = aws rds describe-db-instances `
        --profile $PROFILE `
        --region $REGION `
        --db-instance-identifier $DB `
        --query "DBInstances[0].Endpoint.Address" `
        --output text

    start_tunnel $DB $PORT $ENDPOINT
}

# -----------------------------
# OUTPUT
# -----------------------------
Write-Host "----------------------------------------"
Write-Host "[OK] All tunnels processed for profile: $PROFILE"
Write-Host "[INFO] Connect using:"
Write-Host "Host: 127.0.0.1"
Write-Host "----------------------------------------"

Write-Host "Active tunnels:"

Get-Content $MAP_FILE | ForEach-Object {
    $line = $_.Trim()

    if ($line -match "=") {
        $PORT = ($line.Split("=")[1]).Trim()

        if (is_port_active $PORT) {
            Write-Host "[OK] Port $PORT ACTIVE"
        }
    }
}

Write-Host ""
Write-Host "Verify:"
Write-Host "Test-NetConnection -ComputerName localhost -Port PORT_NUMBER"