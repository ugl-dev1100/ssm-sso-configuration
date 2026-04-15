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
# DETECT DBEAVER WORKSPACE (CORRECT)
# ----------------------------
$dbeaverWorkspaceRoot = "$env:APPDATA\DBeaverData"

if (Test-Path $dbeaverWorkspaceRoot) {
    $dbeaverWorkspace = Get-ChildItem $dbeaverWorkspaceRoot -Directory -Filter "workspace*" `
        | Sort-Object LastWriteTime -Descending `
        | Select-Object -First 1
}

if ($dbeaverWorkspace) {
    $dbeaverDir = "$($dbeaverWorkspace.FullName)\General"
    Write-Host "Using DBeaver workspace: $($dbeaverWorkspace.FullName)"
} else {
    Write-Host "Workspace not found, fallback to .dbeaver4"

    $dbeaverDir = "$HOME\.dbeaver4\General"
    New-Item -ItemType Directory -Path $dbeaverDir -Force | Out-Null
}

$dbeaverFile = "$dbeaverDir\.dbeaver-data-sources.xml"

# Ensure directory exists
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

# ----------------------------
# EMPTY CHECK
# ----------------------------
if (-not $newConnections) {
    Write-Host "No valid DB entries found in .rds-map"
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
# CREATE FILE IF NOT EXISTS
# ----------------------------
if (!(Test-Path $dbeaverFile)) {
    $xmlContent = "<connections>`n$managedBlock`n</connections>"
    $xmlContent | Out-File -FilePath $dbeaverFile -Encoding utf8
    Write-Host "Created DBeaver config"
    return
}

# ----------------------------
# UPDATE EXISTING FILE
# ----------------------------
$contentXml = Get-Content $dbeaverFile -Raw

# Remove old managed block
if ($contentXml -match 'SSM_MANAGED_START') {
    $contentXml = $contentXml -replace '(?s)<!-- SSM_MANAGED_START -->.*?<!-- SSM_MANAGED_END -->', ''
}

# Insert new block
if ($contentXml -match "</connections>") {
    $contentXml = $contentXml -replace '</connections>', "$managedBlock`n</connections>"
} else {
    Write-Host "Invalid config, recreating..."
    $contentXml = "<connections>`n$managedBlock`n</connections>"
}

# Save file
$contentXml | Out-File -FilePath $dbeaverFile -Encoding utf8

Write-Host "DBeaver connections synced"
Write-Host "Restart DBeaver if needed"