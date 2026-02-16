# winway-dev-add-ip.ps1 - Development server Security Group IP add script
# Usage: .\winway-dev-add-ip.ps1 -Profile <profile> -ServerName <server_name>
# Example: .\winway-dev-add-ip.ps1 -Profile winway -ServerName web-dev

param(
  [string]$Profile,
  [string]$ServerName,
  [switch]$Help
)

# ============================================
# Configuration
# ============================================
$REGION = "ap-northeast-2"

# Security Group IDs per server name
$SG_IDS = @{
  "gen-dev"    = "sg-xxxxxxxxxxxxxxxxx"   # winway-gen-dev
  "comp-dev"   = "sg-xxxxxxxxxxxxxxxxx"   # winway-comp-dev
  "web-dev"    = "sg-xxxxxxxxxxxxxxxxx"   # winway-web-dev
  "redhat-dev" = "sg-xxxxxxxxxxxxxxxxx"   # winway-redhat-dev
}
# ============================================

function Show-Usage {
  Write-Host "=========================================="
  Write-Host "  Winway Dev Server - IP Add"
  Write-Host "=========================================="
  Write-Host ""
  Write-Host "Usage: .\winway-dev-add-ip.ps1 -Profile <profile> -ServerName <server_name>"
  Write-Host ""
  Write-Host "Options:"
  Write-Host "  -Profile      AWS CLI profile name"
  Write-Host "  -ServerName   Target server name"
  Write-Host ""
  Write-Host "Example:"
  Write-Host "  .\winway-dev-add-ip.ps1 -Profile winway -ServerName web-dev"
  Write-Host ""
  Write-Host "Available server names:"
  foreach ($key in $SG_IDS.Keys) {
    Write-Host "  - $key"
  }
  Write-Host ""
}

# Show help
if ($Help) {
  Show-Usage
  exit 0
}

# Check required arguments
if (-not $Profile -or -not $ServerName) {
  Show-Usage
  exit 1
}

# Validate server name
$SG_ID = $SG_IDS[$ServerName]
if (-not $SG_ID) {
  Write-Host "❌ Unknown server name: '$ServerName'" -ForegroundColor Red
  Write-Host ""
  Write-Host "Available server names:"
  foreach ($key in $SG_IDS.Keys) {
    Write-Host "  - $key"
  }
  exit 1
}

# 1. Get Access Key ID (last 6 characters) for description
$ACCESS_KEY_FULL = aws configure get aws_access_key_id --profile $Profile 2>$null

if (-not $ACCESS_KEY_FULL) {
  Write-Host "❌ Failed to get Access Key from profile '$Profile'" -ForegroundColor Red
  Write-Host "   Please check if the profile exists: aws configure --profile $Profile"
  exit 1
}

$ACCESS_KEY_SUFFIX = $ACCESS_KEY_FULL.Substring($ACCESS_KEY_FULL.Length - 6)

# 2. Detect current public IP
Write-Host "📍 Detecting public IP..." -ForegroundColor Blue
$MY_IP = (Invoke-WebRequest -Uri "https://checkip.amazonaws.com" -UseBasicParsing).Content.Trim()

if (-not $MY_IP) {
  Write-Host "❌ Failed to detect public IP" -ForegroundColor Red
  exit 1
}

Write-Host "📍 My IP: $MY_IP" -ForegroundColor Green

# 3. Add IP to Security Group (port 22)
$DATE_TAG = Get-Date -Format "MMdd"
$DESCRIPTION = "${ACCESS_KEY_SUFFIX}-${DATE_TAG}"

Write-Host "🔐 Adding IP to Security Group [$ServerName]..." -ForegroundColor Blue
Write-Host "   SG ID: $SG_ID"

aws ec2 authorize-security-group-ingress `
  --group-id $SG_ID `
  --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$MY_IP/32,Description=$DESCRIPTION}]" `
  --profile $Profile `
  --region $REGION 2>$null

if ($LASTEXITCODE -eq 0) {
  Write-Host "✅ IP added successfully" -ForegroundColor Green
  Write-Host "   - IP: $MY_IP"
  Write-Host "   - Server: $ServerName"
  Write-Host "   - Description: $DESCRIPTION"
} else {
  Write-Host "ℹ️  IP already registered or error occurred" -ForegroundColor Yellow
}
