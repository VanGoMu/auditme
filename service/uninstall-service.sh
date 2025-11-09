#!/bin/bash

# Uninstallation script for auditme systemd service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="auditme"
SYSTEMD_DIR="/etc/systemd/system"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$CURRENT_DIR")"

echo -e "${GREEN}=== Auditme Service Uninstaller ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Check if service exists
if [ ! -f "$SYSTEMD_DIR/$SERVICE_NAME.service" ]; then
    echo -e "${YELLOW}Warning: Service is not installed${NC}"
    exit 0
fi

# Stop service if running
if systemctl is-active --quiet "$SERVICE_NAME.service"; then
    echo -e "${YELLOW}Stopping service...${NC}"
    systemctl stop "$SERVICE_NAME.service"
    echo -e "${GREEN}✓${NC} Service stopped"
fi

# Disable service
if systemctl is-enabled --quiet "$SERVICE_NAME.service"; then
    echo -e "${YELLOW}Disabling service...${NC}"
    systemctl disable "$SERVICE_NAME.service"
    echo -e "${GREEN}✓${NC} Service disabled"
fi

# Remove service file
echo -e "${YELLOW}Removing service file...${NC}"
rm -f "$SYSTEMD_DIR/$SERVICE_NAME.service"
echo -e "${GREEN}✓${NC} Service file removed"

# Reload systemd daemon
echo -e "${YELLOW}Reloading systemd daemon...${NC}"
systemctl daemon-reload
systemctl reset-failed
echo -e "${GREEN}✓${NC} Systemd daemon reloaded"

echo ""
echo -e "${GREEN}=== Uninstallation Complete ===${NC}"
echo ""
echo "The service has been removed from your system."
echo "Docker containers are still running. To stop them manually:"
echo "  cd $PROJECT_DIR"
echo "  docker compose down"
echo ""
