#!/bin/bash
# winway-dev-remove-ip.sh - Development server Security Group IP remove script
# Usage: ./winway-dev-remove-ip.sh --profile <profile> --server_name <server_name> [--ip <ip_address>]
# Example: ./winway-dev-remove-ip.sh --profile winway --server_name web-dev
#          ./winway-dev-remove-ip.sh --profile winway --server_name web-dev --ip 1.2.3.4

# ============================================
# Configuration
# ============================================
REGION="ap-northeast-2"

# Security Group IDs per server name
declare -A SG_IDS
SG_IDS["gen-dev"]="sg-xxxxxxxxxxxxxxxxx"       # winway-gen-dev
SG_IDS["comp-dev"]="sg-xxxxxxxxxxxxxxxxx"       # winway-comp-dev
SG_IDS["web-dev"]="sg-xxxxxxxxxxxxxxxxx"        # winway-web-dev
SG_IDS["redhat-dev"]="sg-xxxxxxxxxxxxxxxxx"     # winway-redhat-dev
# ============================================

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
PROFILE=""
SERVER_NAME=""
TARGET_IP=""

while [[ $# -gt 0 ]]; do
  case $1 in
  --profile)
    PROFILE="$2"
    shift 2
    ;;
  --server_name)
    SERVER_NAME="$2"
    shift 2
    ;;
  --ip)
    TARGET_IP="$2"
    shift 2
    ;;
  -h | --help)
    SHOW_HELP=true
    shift
    ;;
  *)
    echo -e "${RED}❌ Unknown option: $1${NC}"
    exit 1
    ;;
  esac
done

show_usage() {
  echo "=========================================="
  echo "  Winway Dev Server - IP Remove"
  echo "=========================================="
  echo ""
  echo "Usage: $0 --profile <profile> --server_name <server_name> [--ip <ip_address>]"
  echo ""
  echo "Options:"
  echo "  --profile      AWS CLI profile name"
  echo "  --server_name  Target server name"
  echo "  --ip           (Optional) Specific IP to remove. If omitted, removes current IP."
  echo ""
  echo "Example:"
  echo "  $0 --profile winway --server_name web-dev"
  echo "  $0 --profile winway --server_name web-dev --ip 1.2.3.4"
  echo ""
  echo "Available server names:"
  for key in "${!SG_IDS[@]}"; do
    echo "  - $key"
  done
  echo ""
}

# Show help
if [ "$SHOW_HELP" = true ]; then
  show_usage
  exit 0
fi

# Check required arguments
if [ -z "$PROFILE" ] || [ -z "$SERVER_NAME" ]; then
  show_usage
  exit 1
fi

# Validate server name
SG_ID="${SG_IDS[$SERVER_NAME]}"
if [ -z "$SG_ID" ]; then
  echo -e "${RED}❌ Unknown server name: '$SERVER_NAME'${NC}"
  echo ""
  echo "Available server names:"
  for key in "${!SG_IDS[@]}"; do
    echo "  - $key"
  done
  exit 1
fi

# If no IP specified, detect current public IP
if [ -z "$TARGET_IP" ]; then
  echo -e "${BLUE}📍 Detecting public IP...${NC}"
  TARGET_IP=$(curl -s https://checkip.amazonaws.com)

  if [ -z "$TARGET_IP" ]; then
    echo -e "${RED}❌ Failed to detect public IP${NC}"
    exit 1
  fi
fi

echo -e "${GREEN}📍 Target IP: $TARGET_IP${NC}"

# Remove IP from Security Group (port 22)
echo -e "${BLUE}🔐 Removing IP from Security Group [$SERVER_NAME]...${NC}"
echo "   SG ID: $SG_ID"

aws ec2 revoke-security-group-ingress \
  --group-id "$SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=${TARGET_IP}/32}]" \
  --profile "$PROFILE" \
  --region "$REGION" 2>/dev/null

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ IP removed successfully${NC}"
  echo "   - IP: $TARGET_IP"
  echo "   - Server: $SERVER_NAME"
else
  echo -e "${YELLOW}ℹ️  IP not found or already removed${NC}"
fi
