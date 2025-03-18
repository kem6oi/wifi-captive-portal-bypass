#!/bin/bash

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use sudo."
   exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Use INTERFACE from environment, fallback to default if not set
INTERFACE=${INTERFACE:-"wlp3s0b1"}

# Check if interface exists
if ! iwconfig "$INTERFACE" > /dev/null 2>&1; then
    echo -e "${RED}Interface $INTERFACE not found. Please check your wireless interface name.${NC}"
    exit 1
fi

# Set interface down
echo -e "${GREEN}Setting $INTERFACE down...${NC}"
ifconfig "$INTERFACE" down

# Change to managed mode
echo -e "${GREEN}Switching $INTERFACE to managed mode...${NC}"
iwconfig "$INTERFACE" mode managed

# Bring interface back up
echo -e "${GREEN}Bringing $INTERFACE up...${NC}"
ifconfig "$INTERFACE" up

# Restart network services
echo -e "${GREEN}Restarting network services...${NC}"
service NetworkManager restart

# Verify mode
echo -e "${GREEN}Current mode:${NC}"
iwconfig "$INTERFACE" | grep Mode

echo -e "${GREEN}Managed mode restored on $INTERFACE.${NC}"