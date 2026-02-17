#!/bin/bash
# winway-dev-add-ip.sh - Development server Security Group IP add script
# Usage: ./winway-dev-add-ip.sh --profile <profile> --server_name <server_name>
# Example: ./winway-dev-add-ip.sh --profile winway --server_name web-dev

# ============================================
# Configuration
# ============================================
REGION="ap-northeast-2"

# Security Group IDs per server name (Bash 3.2 compatible)
get_sg_id() {
  case "$1" in
    gen-dev)    echo "sg-xxxxxxxxxxxxxxxxx" ;;   # winway-gen-dev
    comp-dev)   echo "sg-xxxxxxxxxxxxxxxxx" ;;   # winway-comp-dev
    web-dev)    echo "sg-xxxxxxxxxxxxxxxxx" ;;   # winway-web-dev
    redhat-dev) echo "sg-xxxxxxxxxxxxxxxxx" ;;   # winway-redhat-dev
    *)          echo "" ;;
  esac
}
AVAILABLE_SERVERS="gen-dev comp-dev web-dev redhat-dev"
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
  echo "  Winway Dev Server - IP Add"
  echo "=========================================="
  echo ""
  echo "Usage: $0 --profile <profile> --server_name <server_name>"
  echo ""
  echo "Options:"
  echo "  --profile      AWS CLI profile name"
  echo "  --server_name  Target server name"
  echo ""
  echo "Example:"
  echo "  $0 --profile winway --server_name web-dev"
  echo ""
  echo "Available server names:"
  for key in $AVAILABLE_SERVERS; do
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
SG_ID=$(get_sg_id "$SERVER_NAME")
if [ -z "$SG_ID" ]; then
  echo -e "${RED}❌ Unknown server name: '$SERVER_NAME'${NC}"
  echo ""
  echo "Available server names:"
  for key in $AVAILABLE_SERVERS; do
    echo "  - $key"
  done
  exit 1
fi

# 1. Get Access Key ID (last 6 characters) for description
ACCESS_KEY_FULL=$(aws configure get aws_access_key_id --profile "$PROFILE" 2>/dev/null)

if [ -z "$ACCESS_KEY_FULL" ]; then
  echo -e "${RED}❌ Failed to get Access Key from profile '$PROFILE'${NC}"
  echo "   Please check if the profile exists: aws configure --profile $PROFILE"
  exit 1
fi

ACCESS_KEY_SUFFIX="${ACCESS_KEY_FULL: -6}"

# 2. Detect current public IP
echo -e "${BLUE}📍 Detecting public IP...${NC}"
MY_IP=$(curl -s https://checkip.amazonaws.com)

if [ -z "$MY_IP" ]; then
  echo -e "${RED}❌ Failed to detect public IP${NC}"
  exit 1
fi

echo -e "${GREEN}📍 My IP: $MY_IP${NC}"

# 3. Add IP to Security Group (port 22)
DATE_TAG=$(date +%m%d)
DESCRIPTION="${ACCESS_KEY_SUFFIX}-${DATE_TAG}"

echo -e "${BLUE}🔐 Adding IP to Security Group [$SERVER_NAME]...${NC}"
echo "   SG ID: $SG_ID"

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=${MY_IP}/32,Description=${DESCRIPTION}}]" \
  --profile "$PROFILE" \
  --region "$REGION" 2>/dev/null

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ IP added successfully${NC}"
  echo "   - IP: $MY_IP"
  echo "   - Server: $SERVER_NAME"
  echo "   - Description: $DESCRIPTION"
else
  echo -e "${YELLOW}ℹ️  IP already registered or error occurred${NC}"
fi
