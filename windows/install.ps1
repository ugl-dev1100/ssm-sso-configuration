# # Write-Host "Starting Dev Environment Setup..."

# # # ----------------------------
# # # EXECUTION POLICY
# # # ----------------------------
# # Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# # # ----------------------------
# # # PATH SETUP
# # # ----------------------------
# # $bin = "$env:USERPROFILE\bin"
# # New-Item -ItemType Directory -Force -Path $bin | Out-Null

# # if ($env:PATH -notlike "*$bin*") {
# #     [Environment]::SetEnvironmentVariable(
# #         "PATH",
# #         "$env:PATH;$bin",
# #         "User"
# #     )
# #     Write-Host "Added $bin to PATH"
# # }

# # # ----------------------------
# # # PRE-FLIGHT CHECKS
# # # ----------------------------
# # Write-Host "Running pre-flight checks..."

# # if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
# #     Write-Host "AWS CLI not found"
# # }

# # # ----------------------------
# # # INSTALL AWS CLI (SAFE)
# # # ----------------------------
# # if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
# #     Write-Host "Installing AWS CLI..."

# #     $msi = "$env:TEMP\aws.msi"
# #     Invoke-WebRequest "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $msi

# #     # Try silent install first
# #     Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`" /qn"

# #     # Verify install
# #     if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
# #         Write-Host "Silent install failed. Retrying with UI..."
# #         Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`""
# #     }
# # }

# # # ----------------------------
# # # INSTALL SESSION MANAGER
# # # ----------------------------
# # if (-not (Get-Command session-manager-plugin -ErrorAction SilentlyContinue)) {
# #     Write-Host "Installing Session Manager Plugin..."

# #     $ssm = "$env:TEMP\ssm.exe"
# #     Invoke-WebRequest "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe" -OutFile $ssm

# #     Start-Process $ssm -Wait
# # }

# # # ----------------------------
# # # INSTALL SCRIPTS
# # # ----------------------------
# # Write-Host "Installing scripts..."

# # Get-ChildItem ".\scripts\*.ps1" | ForEach-Object {
# #     Copy-Item $_.FullName $bin -Force
# #     Write-Host "Installed $($_.Name)"
# # }

# # # ----------------------------
# # # RDS MAP SETUP
# # # ----------------------------
# # $rdsMap = "$env:USERPROFILE\.rds-map"

# # if (-not (Test-Path $rdsMap)) {
# #     Write-Host "Creating rds-map..."
# #     Copy-Item ".\templates\rds-map" $rdsMap
# # }

# # # ----------------------------
# # # POWERSHELL PROFILE
# # # ----------------------------
# # $profilePath = $PROFILE
# # New-Item -ItemType File -Force -Path $profilePath | Out-Null

# # Write-Host "Updating PowerShell profile..."

# # $block = @"

# # # >>> SSM_SETUP >>>

# # function aws-auto-login {

# #     if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
# #         return
# #     }

# #     `$profiles = aws configure list-profiles 2>`$null

# #     if (`$profiles -notcontains "uat") {
# #         Write-Host "Skipping uat (profile not configured)"
# #     } else {
# #         aws sts get-caller-identity --profile uat 2>`$null
# #         if (-not `$?) {
# #             Write-Host "Logging into uat..."
# #             aws sso login --profile uat
# #         }
# #     }

# #     if (`$profiles -notcontains "prod") {
# #         Write-Host "Skipping prod (profile not configured)"
# #     } else {
# #         aws sts get-caller-identity --profile prod 2>`$null
# #         if (-not `$?) {
# #             Write-Host "Logging into prod..."
# #             aws sso login --profile prod
# #         }
# #     }
# # }

# # aws-auto-login

# # function uat { win-connect uat }
# # function prod { win-connect prod }
# # function dbuat { rds uat }
# # function dbprod { rds prod }
# # function dbpc { db-pc }

# # # <<< SSM_SETUP <<<
# # "@

# # # Remove old block safely
# # if (Test-Path $profilePath) {
# #     $content = Get-Content $profilePath -Raw
# #     $content = $content -replace '# >>> SSM_SETUP >>>[\s\S]*?# <<< SSM_SETUP <<<', ''
# #     $content | Set-Content $profilePath
# # }

# # Add-Content $profilePath $block

# # # ----------------------------
# # # REFRESH PATH (CURRENT SESSION)
# # # ----------------------------
# # $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + `
# #             [System.Environment]::GetEnvironmentVariable("PATH","User")

# # # ----------------------------
# # # DONE
# # # ----------------------------
# # Write-Host ""
# # Write-Host "Setup Complete!"
# # Write-Host ""
# # Write-Host "Reload PowerShell:"
# # Write-Host "   . `$PROFILE"
# # Write-Host ""
# # Write-Host "Usage:"
# # Write-Host "   uat     - connect to uat servers"
# # Write-Host "   prod    - connect to prod servers"
# # Write-Host "   dbuat   - open tunnels for uat dbs"
# # Write-Host "   dbprod  - open tunnels for prod dbs"
# # Write-Host "   dbpc    - check active ports"

# Write-Host "Starting Dev Environment Setup..."

# # ----------------------------
# # SELF-RELAUNCH WITH BYPASS
# # ----------------------------
# if ($env:RUN_WITH_BYPASS -ne "1") {
#     Write-Host "Restarting script with ExecutionPolicy Bypass..."
#     $env:RUN_WITH_BYPASS = "1"
#     Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
#     exit
# }

# # ----------------------------
# # SAFE EXECUTION POLICY
# # ----------------------------
# try {
#     $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
#     if ($currentPolicy -ne "RemoteSigned") {
#         Write-Host "Setting execution policy to RemoteSigned..."
#         Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
#     }
# } catch {
#     Write-Host "Warning: Unable to set execution policy"
# }

# # ----------------------------
# # PATH SETUP
# # ----------------------------
# $bin = "$env:USERPROFILE\bin"
# New-Item -ItemType Directory -Force -Path $bin | Out-Null

# if ($env:PATH -notlike "*$bin*") {
#     [Environment]::SetEnvironmentVariable(
#         "PATH",
#         "$env:PATH;$bin",
#         "User"
#     )
#     Write-Host "Added $bin to PATH"
# }

# # ----------------------------
# # HELPER: RETRY FUNCTION
# # ----------------------------
# function Invoke-Retry {
#     param (
#         [scriptblock]$Script,
#         [int]$Retries = 3
#     )

#     for ($i = 1; $i -le $Retries; $i++) {
#         try {
#             & $Script
#             return
#         } catch {
#             if ($i -eq $Retries) {
#                 throw
#             }
#             Write-Host "Retry $i failed. Retrying..."
#             Start-Sleep -Seconds 2
#         }
#     }
# }

# # ----------------------------
# # PRE-FLIGHT CHECKS
# # ----------------------------
# Write-Host "Running pre-flight checks..."

# function Test-AwsCli {
#     aws --version 2>$null
#     return $LASTEXITCODE -eq 0
# }

# # ----------------------------
# # INSTALL AWS CLI
# # ----------------------------
# if (-not (Test-AwsCli)) {
#     Write-Host "Installing AWS CLI..."

#     $msi = "$env:TEMP\aws.msi"

#     Invoke-Retry {
#         Invoke-WebRequest "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $msi -ErrorAction Stop
#     }

#     Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`" /qn"

#     if (-not (Test-AwsCli)) {
#         Write-Host "Silent install failed. Retrying with UI..."
#         Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`""
#     }
# } else {
#     Write-Host "AWS CLI already installed"
# }

# # ----------------------------
# # INSTALL SESSION MANAGER
# # ----------------------------
# if (-not (Get-Command session-manager-plugin -ErrorAction SilentlyContinue)) {
#     Write-Host "Installing Session Manager Plugin..."

#     $ssm = "$env:TEMP\ssm.exe"

#     Invoke-Retry {
#         Invoke-WebRequest "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe" -OutFile $ssm -ErrorAction Stop
#     }

#     Start-Process $ssm -Wait
# } else {
#     Write-Host "Session Manager Plugin already installed"
# }

# # ----------------------------
# # INSTALL SCRIPTS
# # ----------------------------
# Write-Host "Installing scripts..."

# $scriptsPath = ".\scripts"
# if (Test-Path $scriptsPath) {
#     Get-ChildItem "$scriptsPath\*.ps1" | ForEach-Object {
#         Copy-Item $_.FullName $bin -Force
#         Write-Host "Installed $($_.Name)"
#     }
# } else {
#     Write-Host "Scripts folder not found, skipping..."
# }

# # ----------------------------
# # RDS MAP SETUP
# # ----------------------------
# $rdsMap = "$env:USERPROFILE\.rds-map"

# if (-not (Test-Path $rdsMap)) {
#     if (Test-Path ".\templates\rds-map") {
#         Write-Host "Creating rds-map..."
#         Copy-Item ".\templates\rds-map" $rdsMap
#     } else {
#         Write-Host "Template rds-map not found, skipping..."
#     }
# }

# # ----------------------------
# # DBeaver CONFIG GENERATION
# # ----------------------------
# Write-Host "Configuring DBeaver connections..."

# $dbScript = "$PSScriptRoot\scripts\generate-dbeaver-config.ps1"

# if (Test-Path $dbScript) {
#     & $dbScript
# } else {
#     Write-Host "⚠️ generate-dbeaver-config.ps1 not found"
# }

# # ----------------------------
# # POWERSHELL PROFILE
# # ----------------------------
# $profilePath = $PROFILE
# New-Item -ItemType File -Force -Path $profilePath | Out-Null

# Write-Host "Updating PowerShell profile..."

# $block = @"

# # >>> SSM_SETUP >>>

# function aws-auto-login {

#     if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
#         return
#     }

#     `$profiles = aws configure list-profiles 2>`$null

#     if (`$profiles -contains "uat") {
#         aws sts get-caller-identity --profile uat 2>`$null
#         if (-not `$?) {
#             Write-Host "Logging into uat..."
#             aws sso login --profile uat
#         }
#     }

#     if (`$profiles -contains "prod") {
#         aws sts get-caller-identity --profile prod 2>`$null
#         if (-not `$?) {
#             Write-Host "Logging into prod..."
#             aws sso login --profile prod
#         }
#     }
# }

# aws-auto-login

# function uat { win-connect uat }
# function prod { win-connect prod }
# function dbuat { rds uat }
# function dbprod { rds prod }
# function dbpc { db-pc }

# # <<< SSM_SETUP <<<

# "@

# if (Test-Path $profilePath) {
#     $content = Get-Content $profilePath -Raw
#     $content = $content -replace '# >>> SSM_SETUP >>>[\s\S]*?# <<< SSM_SETUP <<<', ''
#     $content | Set-Content $profilePath
# }

# Add-Content $profilePath $block

# # ----------------------------
# # REFRESH PATH
# # ----------------------------
# $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + `
#             [System.Environment]::GetEnvironmentVariable("PATH","User")

# # ----------------------------
# # DONE
# # ----------------------------
# Write-Host ""
# Write-Host "✅ Setup Complete!"
# Write-Host ""
# Write-Host "Reload PowerShell:"
# Write-Host "   . `$PROFILE"
# Write-Host ""
# Write-Host "Usage:"
# Write-Host "   uat     - connect to uat servers"
# Write-Host "   prod    - connect to prod servers"
# Write-Host "   dbuat   - open tunnels for uat dbs"
# Write-Host "   dbprod  - open tunnels for prod dbs"
# Write-Host "   dbpc    - check active ports"

param(
    [string]$RUN_WITH_BYPASS
)

# ----------------------------
# SELF-RELAUNCH WITH BYPASS
# ----------------------------
if ($RUN_WITH_BYPASS -ne "1") {
    Write-Host "Starting Dev Environment Setup..."
    Write-Host "Restarting script with ExecutionPolicy Bypass..."

    Start-Process powershell -Verb RunAs -ArgumentList @(
        "-ExecutionPolicy Bypass",
        "-NoProfile",
        "-File `"$PSCommandPath`"",
        "-RUN_WITH_BYPASS 1"
    )

    exit
}

Write-Host "Starting Dev Environment Setup..."

# ----------------------------
# SAFE EXECUTION POLICY
# ----------------------------
try {
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($currentPolicy -ne "RemoteSigned") {
        Write-Host "Setting execution policy to RemoteSigned..."
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    }
} catch {
    Write-Host "Warning: Unable to set execution policy"
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
# RETRY FUNCTION
# ----------------------------
function Invoke-Retry {
    param (
        [scriptblock]$Script,
        [int]$Retries = 3
    )

    for ($i = 1; $i -le $Retries; $i++) {
        try {
            & $Script
            return
        } catch {
            if ($i -eq $Retries) { throw }
            Write-Host "Retry $i failed. Retrying..."
            Start-Sleep -Seconds 2
        }
    }
}

# ----------------------------
# CHECK AWS CLI
# ----------------------------
function Test-AwsCli {
    aws --version 2>$null
    return $LASTEXITCODE -eq 0
}

# ----------------------------
# INSTALL AWS CLI
# ----------------------------
if (-not (Test-AwsCli)) {
    Write-Host "Installing AWS CLI..."

    $msi = "$env:TEMP\aws.msi"

    Invoke-Retry {
        Invoke-WebRequest "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $msi -ErrorAction Stop
    }

    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`" /qn"

    if (-not (Test-AwsCli)) {
        Write-Host "Retrying with UI..."
        Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`""
    }
} else {
    Write-Host "AWS CLI already installed"
}

# ----------------------------
# INSTALL SESSION MANAGER
# ----------------------------
if (-not (Get-Command session-manager-plugin -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Session Manager Plugin..."

    $ssm = "$env:TEMP\ssm.exe"

    Invoke-Retry {
        Invoke-WebRequest "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe" -OutFile $ssm -ErrorAction Stop
    }

    Start-Process $ssm -Wait
} else {
    Write-Host "Session Manager Plugin already installed"
}

# ----------------------------
# INSTALL SCRIPTS
# ----------------------------
Write-Host "Installing scripts..."

$bin = "$env:USERPROFILE\bin"
$scriptsPath = "$PSScriptRoot\scripts"

if (Test-Path $scriptsPath) {
    Get-ChildItem "$scriptsPath\*.ps1" | ForEach-Object {
        Copy-Item $_.FullName $bin -Force
        Write-Host "Installed $($_.Name)"
    }
}

# ----------------------------
# RDS MAP SETUP
# ----------------------------
$rdsMap = "$env:USERPROFILE\.rds-map"

if (-not (Test-Path $rdsMap)) {
    Copy-Item "$PSScriptRoot\templates\rds-map" $rdsMap
    Write-Host "Created .rds-map"
}

# ----------------------------
# DBeaver CONFIG GENERATION
# ----------------------------
Write-Host "Configuring DBeaver connections..."

$dbScript = "$PSScriptRoot\scripts\generate-dbeaver-config.ps1"

if (Test-Path $dbScript) {
    try {
        & $dbScript
        Write-Host "✅ DBeaver configuration completed"
    } catch {
        Write-Host "⚠️ DBeaver config failed: $_"
    }
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
    `$profiles = aws configure list-profiles 2>`$null

    if (`$profiles -contains "uat") {
        aws sts get-caller-identity --profile uat 2>`$null
        if (-not `$?) { aws sso login --profile uat }
    }

    if (`$profiles -contains "prod") {
        aws sts get-caller-identity --profile prod 2>`$null
        if (-not `$?) { aws sso login --profile prod }
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
# DONE
# ----------------------------
Write-Host ""
Write-Host "✅ Setup Complete!"
Write-Host ""
Write-Host "Reload PowerShell:"
Write-Host "   . `$PROFILE"
Write-Host ""
Write-Host "Open DBeaver → DB connections are ready 🚀"