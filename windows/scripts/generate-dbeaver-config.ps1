# ----------------------------
# CONFIG
# ----------------------------
$mapFile = "$HOME\.rds-map"
$dbeaverBase = "$HOME\.dbeaver4"
$dbeaverDir = "$dbeaverBase\General"
$dbeaverFile = "$dbeaverDir\.dbeaver-data-sources.xml"

Write-Host "🔧 Generating DBeaver configuration..."

# ----------------------------
# VALIDATION
# ----------------------------
if (!(Test-Path $mapFile)) {
    Write-Host "❌ .rds-map not found"
    exit
}

if (!(Test-Path $dbeaverBase)) {
    Write-Host "⚠️ Open DBeaver once and re-run"
    return
}

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
    "<connections>`n$managedBlock`n</connections>" | Out-File $dbeaverFile
    Write-Host "✅ Created config"
    return
}

$contentXml = Get-Content $dbeaverFile -Raw

if ($contentXml -match 'SSM_MANAGED_START') {
    $contentXml = $contentXml -replace '(?s)<!-- SSM_MANAGED_START -->.*?<!-- SSM_MANAGED_END -->', ''
}

if ($contentXml -match "</connections>") {
    $contentXml = $contentXml -replace '</connections>', "$managedBlock`n</connections>"
} else {
    $contentXml = "<connections>`n$managedBlock`n</connections>"
}

$contentXml | Out-File $dbeaverFile

Write-Host "✅ DBeaver connections synced"
Write-Host "👉 Restart DBeaver if needed"