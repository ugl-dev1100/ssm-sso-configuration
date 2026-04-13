Write-Host "Starting Dev Environment Setup..."

# ----------------------------
# EXECUTION POLICY
# ----------------------------
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# ----------------------------
# PATH SETUP
# ----------------------------
$bin = "$env:USERPROFILE\bin"
New-Item -ItemType Directory -Force -Path $bin | Out-Null

if ($env:PATH -notlike "*$bin*") {
    [Environment]::SetEnvironmentVariable(
        "PATH",
        "$env:PATH;$bin",
        "User"
    )
    Write-Host "Added $bin to PATH"
}

# ----------------------------
# PRE-FLIGHT CHECKS
# ----------------------------
Write-Host "Running pre-flight checks..."

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "AWS CLI not found"
}

# ----------------------------
# INSTALL AWS CLI
# ----------------------------
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "Installing AWS CLI..."
    Invoke-WebRequest "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile "$env:TEMP\aws.msi"
    Start-Process msiexec.exe -Wait -ArgumentList "/i $env:TEMP\aws.msi /quiet"
}

# ----------------------------
# INSTALL SESSION MANAGER
# ----------------------------
if (-not (Get-Command session-manager-plugin -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Session Manager Plugin..."
    Invoke-WebRequest "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe" -OutFile "$env:TEMP\ssm.exe"
    Start-Process "$env:TEMP\ssm.exe" -Wait
}

# ----------------------------
# INSTALL SCRIPTS
# ----------------------------
Write-Host "Installing scripts..."

Get-ChildItem ".\scripts\*.ps1" | ForEach-Object {
    Copy-Item $_.FullName $bin -Force
    Write-Host "Installed $($_.Name)"
}

# ----------------------------
# RDS MAP SETUP
# ----------------------------
$rdsMap = "$env:USERPROFILE\.rds-map"

if (-not (Test-Path $rdsMap)) {
    Write-Host "Creating rds-map..."
    Copy-Item ".\templates\rds-map" $rdsMap
}

# ----------------------------
# POWERSHELL PROFILE
# ----------------------------
$profilePath = $PROFILE
New-Item -ItemType File -Force -Path $profilePath | Out-Null

Write-Host "Updating PowerShell profile..."

$block = @"

# >>> SSM_SETUP >>>

function aws-auto-login {
    try { aws sts get-caller-identity --profile uat | Out-Null }
    catch { aws sso login --profile uat }

    try { aws sts get-caller-identity --profile prod | Out-Null }
    catch { aws sso login --profile prod }
}

aws-auto-login

function uat { win-connect uat }
function prod { win-connect prod }
function dbuat { rds uat }
function dbprod { rds prod }
function dbpc { db-pc }

# <<< SSM_SETUP <<<
"@

# Remove old block safely
if (Test-Path $profilePath) {
    $content = Get-Content $profilePath -Raw
    $content = $content -replace '# >>> SSM_SETUP >>>[\s\S]*?# <<< SSM_SETUP <<<', ''
    $content | Set-Content $profilePath
}

Add-Content $profilePath $block

# ----------------------------
# DONE
# ----------------------------
Write-Host ""
Write-Host "Setup Complete!"
Write-Host ""
Write-Host "Reload PowerShell:"
Write-Host "   . `$PROFILE"
Write-Host ""
Write-Host "Usage:"
Write-Host "   uat     - connect to uat servers"
Write-Host "   prod    - connect to prod servers"
Write-Host "   dbuat   - open tunnels for uat dbs"
Write-Host "   dbprod  - open tunnels for prod dbs"
Write-Host "   dbpc    - check active ports"