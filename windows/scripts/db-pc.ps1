param()

$LOCALHOST = "127.0.0.1"

# ----------------------------
# FUNCTION (better check)
# ----------------------------
function test_port($port) {
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $client.Connect($LOCALHOST, $port)
        $client.Close()
        return $true
    } catch {
        return $false
    }
}

# ----------------------------
# UAT PORTS
# ----------------------------
Write-Host "Checking UAT Ports..."

$uatPorts = @(3307, 3308, 3309)

foreach ($port in $uatPorts) {
    if (test_port $port) {
        Write-Host "[OK] UAT Port $port is OPEN"
    } else {
        Write-Host "[CLOSED] UAT Port $port is CLOSED"
    }
}

# ----------------------------
# PROD PORTS
# ----------------------------
Write-Host ""
Write-Host "Checking PROD Ports..."

$prodPorts = @(3411, 3412, 3413, 3414, 3415, 3416, 3417)

foreach ($port in $prodPorts) {
    if (test_port $port) {
        Write-Host "[OK] PROD Port $port is OPEN"
    } else {
        Write-Host "[CLOSED] PROD Port $port is CLOSED"
    }
}

# ----------------------------
# DONE
# ----------------------------
Write-Host ""
Write-Host "----------------------------------------"
Write-Host "[DONE] Port check completed"