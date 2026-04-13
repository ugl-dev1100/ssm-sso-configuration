param(
    [string]$PROFILE
)

if (-not $PROFILE) {
    Write-Host "Usage: aws-login <profile>"
    exit 1
}

Write-Host "Checking SSO for $PROFILE..."

$result = aws sts get-caller-identity --profile $PROFILE 2>$null

if (-not $?) {
    Write-Host "Logging in..."
    aws sso login --profile $PROFILE
}

Write-Host "Ready: $PROFILE"