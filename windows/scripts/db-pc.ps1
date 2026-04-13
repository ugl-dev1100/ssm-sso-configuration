$HOST = "127.0.0.1"

# ----------------------------
# UAT PORTS
# ----------------------------
Write-Host "🔍 Checking UAT Ports..."

$uatPorts = @(3307, 3308, 3309)

foreach ($port in $uatPorts) {
    $result = Test-NetConnection -ComputerName $HOST -Port $port -WarningAction SilentlyContinue

    if ($result.TcpTestSucceeded) {
        Write-Host "✅ UAT Port $port is OPEN"
    } else {
        Write-Host "❌ UAT Port $port is CLOSED"
    }
}

# ----------------------------
# PROD PORTS
# ----------------------------
Write-Host ""
Write-Host "🔍 Checking PROD Ports..."

$prodPorts = 3411..3417

foreach ($port in $prodPorts) {
    $result = Test-NetConnection -ComputerName $HOST -Port $port -WarningAction SilentlyContinue

    if ($result.TcpTestSucceeded) {
        Write-Host "✅ PROD Port $port is OPEN"
    } else {
        Write-Host "❌ PROD Port $port is CLOSED"
    }
}

# ----------------------------
# DONE
# ----------------------------
Write-Host ""
Write-Host "----------------------------------------"
Write-Host "✅ Port check completed"