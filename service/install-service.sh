#!/bin/bash

# Installation script for auditme systemd service
# This script installs and enables the Docker Compose monitoring stack as a system service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="auditme"
SERVICE_FILE="auditme.service"
SYSTEMD_DIR="/etc/systemd/system"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$CURRENT_DIR")"

echo -e "${GREEN}=== Auditme Service Installer ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Check if Docker Compose is installed
if ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose is not installed${NC}"
    exit 1
fi

# Check if envsubst is installed (part of gettext package)
if ! command -v envsubst &> /dev/null; then
    echo -e "${YELLOW}Warning: envsubst not found. Installing gettext package...${NC}"
    apt-get update && apt-get install -y gettext-base
fi

# Check if service file exists
if [ ! -f "$CURRENT_DIR/$SERVICE_FILE" ]; then
    echo -e "${RED}Error: Service file not found: $CURRENT_DIR/$SERVICE_FILE${NC}"
    exit 1
fi

# Set environment variable for envsubst
export AUDITME_PROJECT_DIR="$PROJECT_DIR"

echo -e "${YELLOW}Installing service...${NC}"
echo "Project directory: $AUDITME_PROJECT_DIR"

# Use envsubst to replace environment variables in service file
TEMP_SERVICE_FILE=$(mktemp)
envsubst < "$CURRENT_DIR/$SERVICE_FILE" > "$TEMP_SERVICE_FILE"

# Copy service file to systemd directory
cp "$TEMP_SERVICE_FILE" "$SYSTEMD_DIR/$SERVICE_NAME.service"
rm "$TEMP_SERVICE_FILE"
chmod 644 "$SYSTEMD_DIR/$SERVICE_NAME.service"

echo -e "${GREEN}✓${NC} Service file installed to $SYSTEMD_DIR/$SERVICE_NAME.service"

# Reload systemd daemon
echo -e "${YELLOW}Reloading systemd daemon...${NC}"
systemctl daemon-reload
echo -e "${GREEN}✓${NC} Systemd daemon reloaded"

# Enable service
echo -e "${YELLOW}Enabling service...${NC}"
systemctl enable "$SERVICE_NAME.service"
echo -e "${GREEN}✓${NC} Service enabled (will start on boot)"

# Ask if user wants to start now
echo ""
read -p "Do you want to start the service now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Starting service...${NC}"
    systemctl start "$SERVICE_NAME.service"
    sleep 2
    
    # Check status
    if systemctl is-active --quiet "$SERVICE_NAME.service"; then
        echo -e "${GREEN}✓${NC} Service started successfully"
    else
        echo -e "${RED}✗${NC} Service failed to start"
        echo -e "${YELLOW}Check status with: systemctl status $SERVICE_NAME${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo ""
echo "Service commands:"
echo "  Start:   sudo systemctl start $SERVICE_NAME"
echo "  Stop:    sudo systemctl stop $SERVICE_NAME"
echo "  Restart: sudo systemctl restart $SERVICE_NAME"
echo "  Status:  sudo systemctl status $SERVICE_NAME"
echo "  Logs:    sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "The service will automatically start on system boot."
echo ""
