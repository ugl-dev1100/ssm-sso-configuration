$mapFile = "$HOME\.rds-map"

Write-Host "Generating DBeaver JSON configuration..."

if (!(Test-Path $mapFile)) {
    Write-Host "ERROR: .rds-map not found"
    exit
}

# ----------------------------
# DETECT WORKSPACE
# ----------------------------
$dbeaverWorkspace = Get-ChildItem "$env:APPDATA\DBeaverData" -Directory -Filter "workspace*" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $dbeaverWorkspace) {
    Write-Host "ERROR: DBeaver workspace not found"
    return
}

$generalPath = "$($dbeaverWorkspace.FullName)\General"
$jsonFile = "$generalPath\data-sources.json"

Write-Host "Using workspace: $($dbeaverWorkspace.FullName)"

# ----------------------------
# BUILD CONNECTIONS
# ----------------------------
$dataSources = @{}

Get-Content $mapFile | ForEach-Object {

    $line = $_.Trim()

    if ($line -match "^\s*$" -or $line -match "^\[") { return }

    if ($line -match "=") {
        $parts = $line.Split("=")
        $name = $parts[0].Trim()
        $port = $parts[1].Trim()

        $id = [guid]::NewGuid().ToString()

        $dataSources[$id] = @{
            provider = "mysql"
            name     = $name
            configuration = @{
                host = "127.0.0.1"
                port = $port
                database = $name
            }
        }
    }
}

if ($dataSources.Count -eq 0) {
    Write-Host "No DB entries found"
    return
}

# ----------------------------
# WRITE JSON
# ----------------------------
$jsonObject = @{
    connections = $dataSources
}

$jsonObject | ConvertTo-Json -Depth 5 | Out-File $jsonFile -Encoding utf8

Write-Host "DBeaver JSON config created"
Write-Host "Restart DBeaver"