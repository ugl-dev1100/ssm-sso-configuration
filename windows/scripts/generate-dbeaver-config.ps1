# ----------------------------
# CONFIG
# ----------------------------
$mapFile = "$HOME\.rds-map"

Write-Host "Generating DBeaver configuration..."

if (!(Test-Path $mapFile)) {
    Write-Host "ERROR: .rds-map not found"
    exit
}

# ----------------------------
# DETECT WORKSPACE
# ----------------------------
$dbeaverWorkspaceRoot = "$env:APPDATA\DBeaverData"

if (Test-Path $dbeaverWorkspaceRoot) {
    $dbeaverWorkspace = Get-ChildItem $dbeaverWorkspaceRoot -Directory -Filter "workspace*" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

if ($dbeaverWorkspace) {
    $dbeaverDir = "$($dbeaverWorkspace.FullName)\General"
    Write-Host "Using workspace: $($dbeaverWorkspace.FullName)"
} else {
    $dbeaverDir = "$HOME\.dbeaver4\General"
    New-Item -ItemType Directory -Path $dbeaverDir -Force | Out-Null
}

$dbeaverFile = "$dbeaverDir\.dbeaver-data-sources.xml"

if (!(Test-Path $dbeaverDir)) {
    New-Item -ItemType Directory -Path $dbeaverDir -Force | Out-Null
}

# ----------------------------
# READ MAP
# ----------------------------
$content = Get-Content $mapFile
$newConnections = ""

foreach ($line in $content) {

    if ($line -match "^\s*$" -or $line -match "^\[") { continue }

    if ($line -match "=") {
        $parts = $line.Split("=")
        $name = $parts[0].Trim()
        $port = $parts[1].Trim()

        $uuid = [guid]::NewGuid().ToString()

        $newConnections += @"
<data-source id="$uuid" name="$name" driver="mysql">
    <configuration>
        <host>127.0.0.1</host>
        <port>$port</port>
        <database>$name</database>
    </configuration>
</data-source>
"@
    }
}

if (-not $newConnections) {
    Write-Host "No DB entries found"
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
    $xmlContent = "<data-sources>`n$managedBlock`n</data-sources>"
    $xmlContent | Out-File $dbeaverFile -Encoding utf8
    Write-Host "Created config"
    return
}

$contentXml = Get-Content $dbeaverFile -Raw

# Remove old block
if ($contentXml -match 'SSM_MANAGED_START') {
    $contentXml = $contentXml -replace '(?s)<!-- SSM_MANAGED_START -->.*?<!-- SSM_MANAGED_END -->', ''
}

# Insert new block
if ($contentXml -match "</data-sources>") {
    $contentXml = $contentXml -replace '</data-sources>', "$managedBlock`n</data-sources>"
} else {
    $contentXml = "<data-sources>`n$managedBlock`n</data-sources>"
}

$contentXml | Out-File $dbeaverFile -Encoding utf8

Write-Host "DBeaver connections synced"
Write-Host "Restart DBeaver"