Write-Host "Starting Dev Environment Setup..."

# ----------------------------
# SAFE EXECUTION POLICY (NO ADMIN NEEDED)
# ----------------------------
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
} catch {
    Write-Host "Execution policy could not be set, continuing..."
}

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
# INSTALL AWS CLI (SAFE)
# ----------------------------
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "Installing AWS CLI..."

    $msi = "$env:TEMP\aws.msi"
    Invoke-WebRequest "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $msi

    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`" /qn"

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Host "Silent install failed. Retrying with UI..."
        Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`""
    }
}

# ----------------------------
# INSTALL SESSION MANAGER
# ----------------------------
if (-not (Get-Command session-manager-plugin -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Session Manager Plugin..."

    $ssm = "$env:TEMP\ssm.exe"
    Invoke-WebRequest "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe" -OutFile $ssm

    Start-Process $ssm -Wait
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

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        return
    }

    `$profiles = aws configure list-profiles 2>`$null

    if (`$profiles -notcontains "uat") {
        Write-Host "Skipping uat (profile not configured)"
    } else {
        aws sts get-caller-identity --profile uat 2>`$null
        if (-not `$?) {
            Write-Host "Logging into uat..."
            aws sso login --profile uat
        }
    }

    if (`$profiles -notcontains "prod") {
        Write-Host "Skipping prod (profile not configured)"
    } else {
        aws sts get-caller-identity --profile prod 2>`$null
        if (-not `$?) {
            Write-Host "Logging into prod..."
            aws sso login --profile prod
        }
    }
}

aws-auto-login

function uat { win-connect uat }
function prod { win-connect prod }
function dbuat { rds uat }
function dbprod { rds prod }
function dbpc { db-pc }

# <<< SSM_SETUP <<<
"@

if (Test-Path $profilePath) {
    $content = Get-Content $profilePath -Raw
    $content = $content -replace '# >>> SSM_SETUP >>>[\s\S]*?# <<< SSM_SETUP <<<', ''
    $content | Set-Content $profilePath
}

Add-Content $profilePath $block

# ----------------------------
# REFRESH PATH (CURRENT SESSION)
# ----------------------------
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + `
            [System.Environment]::GetEnvironmentVariable("PATH","User")

# ----------------------------
# DONE
# ----------------------------
Write-Host ""
Write-Host "Setup Complete!"
Write-Host ""
Write-Host "Reload PowerShell:"
Write-Host "   . `$PROFILE"
Write-Host ""