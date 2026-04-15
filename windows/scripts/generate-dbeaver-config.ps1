# ----------------------------
# CONFIG
# ----------------------------
$mapFile = "$HOME\.rds-map"

Write-Host "Generating DBeaver configuration..."

# ----------------------------
# VALIDATION
# ----------------------------
if (!(Test-Path $mapFile)) {
    Write-Host "ERROR: .rds-map not found"
    exit
}

# ----------------------------
# DETECT DBEAVER DIRECTORY
# ----------------------------
$dbeaverBase = Get-ChildItem "$HOME" -Directory -Filter ".dbeaver*" `
    | Sort-Object LastWriteTime -Descending `
    | Select-Object -First 1

if (-not $dbeaverBase) {
    Write-Host "No DBeaver directory found, creating default..."
    $dbeaverBase = New-Item -ItemType Directory -Path "$HOME\.dbeaver4"
} 

$dbeaverBasePath = $dbeaverBase.FullName
$dbeaverDir = "$dbeaverBasePath\General"
$dbeaverFile = "$dbeaverDir\.dbeaver-data-sources.xml"

Write-Host "Using DBeaver path: $dbeaverBasePath"

# Ensure directories
if (!(Test-Path $dbeaverDir)) {
    New-Item -ItemType Directory -Path $dbeaverDir -Force | Out-Null
}

# ----------------------------
# READ MAP
# ----------------------------
$content = Get-Content $mapFile
$newConnections = ""

foreach ($line in $content) {

    if ($line -match "^\s*$" -or $line -match "^\[") {
        continue
    }

    if ($line -match "=") {
        $parts = $line.Split("=")
        $name = $parts[0].Trim()
        $port = $parts[1].Trim()

        if (-not $name -or -not $port) { continue }

        $uuid = [guid]::NewGuid().ToString()

        $newConnections += @"
<connection id="$uuid" name="$name">
    <driver>mysql</driver>
    <configuration>
        <host>127.0.0.1</host>
        <port>$port</port>
        <database>$name</database>
    </configuration>
</connection>
"@
    }
}

if (-not $newConnections) {
    Write-Host "No valid DB entries found"
    return
}

# ----------------------------
# MANAGED BLOCK
# ----------------------------
$managedBlock = @"
<!-- SSM_MANAGED_START -->
$newConnections
<!-- SSM_MANAGED_END -->
"@

# ----------------------------
# CREATE / UPDATE
# ----------------------------
if (!(Test-Path $dbeaverFile)) {
    $xmlContent = "<connections>`n$managedBlock`n</connections>"
    $xmlContent | Out-File -FilePath $dbeaverFile -Encoding utf8
    Write-Host "Created DBeaver config"
    return
}

$contentXml = Get-Content $dbeaverFile -Raw

if ($contentXml -match 'SSM_MANAGED_START') {
    $contentXml = $contentXml -replace '(?s)<!-- SSM_MANAGED_START -->.*?<!-- SSM_MANAGED_END -->', ''
}

if ($contentXml -match "</connections>") {
    $contentXml = $contentXml -replace '</connections>', "$managedBlock`n</connections>"
} else {
    Write-Host "Invalid config, recreating..."
    $contentXml = "<connections>`n$managedBlock`n</connections>"
}

$contentXml | Out-File -FilePath $dbeaverFile -Encoding utf8

Write-Host "DBeaver connections synced"
Write-Host "Restart DBeaver if needed"