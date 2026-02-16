# winway-dev-remove-ip.ps1 - Development server Security Group IP remove script
# Usage: .\winway-dev-remove-ip.ps1 -Profile <profile> -ServerName <server_name> [-IP <ip_address>]
# Example: .\winway-dev-remove-ip.ps1 -Profile winway -ServerName web-dev
#          .\winway-dev-remove-ip.ps1 -Profile winway -ServerName web-dev -IP 1.2.3.4

param(
  [string]$Profile,
  [string]$ServerName,
  [string]$IP,
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
  Write-Host "  Winway Dev Server - IP Remove"
  Write-Host "=========================================="
  Write-Host ""
  Write-Host "Usage: .\winway-dev-remove-ip.ps1 -Profile <profile> -ServerName <server_name> [-IP <ip_address>]"
  Write-Host ""
  Write-Host "Options:"
  Write-Host "  -Profile      AWS CLI profile name"
  Write-Host "  -ServerName   Target server name"
  Write-Host "  -IP           (Optional) Specific IP to remove. If omitted, removes current IP."
  Write-Host ""
  Write-Host "Example:"
  Write-Host "  .\winway-dev-remove-ip.ps1 -Profile winway -ServerName web-dev"
  Write-Host "  .\winway-dev-remove-ip.ps1 -Profile winway -ServerName web-dev -IP 1.2.3.4"
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

# If no IP specified, detect current public IP
$TARGET_IP = $IP
if (-not $TARGET_IP) {
  Write-Host "📍 Detecting public IP..." -ForegroundColor Blue
  $TARGET_IP = (Invoke-WebRequest -Uri "https://checkip.amazonaws.com" -UseBasicParsing).Content.Trim()

  if (-not $TARGET_IP) {
    Write-Host "❌ Failed to detect public IP" -ForegroundColor Red
    exit 1
  }
}

Write-Host "📍 Target IP: $TARGET_IP" -ForegroundColor Green

# Remove IP from Security Group (port 22)
Write-Host "🔐 Removing IP from Security Group [$ServerName]..." -ForegroundColor Blue
Write-Host "   SG ID: $SG_ID"

aws ec2 revoke-security-group-ingress `
  --group-id $SG_ID `
  --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$TARGET_IP/32}]" `
  --profile $Profile `
  --region $REGION 2>$null

if ($LASTEXITCODE -eq 0) {
  Write-Host "✅ IP removed successfully" -ForegroundColor Green
  Write-Host "   - IP: $TARGET_IP"
  Write-Host "   - Server: $ServerName"
} else {
  Write-Host "ℹ️  IP not found or already removed" -ForegroundColor Yellow
}
