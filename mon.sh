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

# Stop network managers that might interfere
echo -e "${GREEN}Stopping network services...${NC}"
airmon-ng check kill

# Set interface down
echo -e "${GREEN}Setting $INTERFACE down...${NC}"
ifconfig "$INTERFACE" down

# Change to monitor mode
echo -e "${GREEN}Enabling monitor mode on $INTERFACE...${NC}"
airmon-ng start "$INTERFACE"

# Get the new monitor mode interface name
MONITOR_INTERFACE=$(iwconfig 2>/dev/null | grep "Mode:Monitor" | awk '{print $1}')
if [ -z "$MONITOR_INTERFACE" ]; then
    echo -e "${RED}Failed to enable monitor mode${NC}"
    exit 1
fi

# Start airodump-ng
echo -e "${GREEN}Starting airodump-ng on $MONITOR_INTERFACE...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop capturing${NC}"
airodump-ng "$MONITOR_INTERFACE"