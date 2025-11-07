#!/bin/bash
# Monitor Mode Script
# Purpose: Enables monitor mode for WiFi packet analysis
# Note: This is separate from captive portal bypass functionality

# run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use sudo."
   exit 1
fi


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Use INTERFACE from environment, fallback to default if not set
INTERFACE=${INTERFACE:-"wlp3s0b1"}

# Check if interface exists
if ! iw dev "$INTERFACE" info > /dev/null 2>&1; then
    echo -e "${RED}Interface $INTERFACE not found. Please check your wireless interface name.${NC}"
    exit 1
fi

# Check if airmon-ng is available
if ! command -v airmon-ng &> /dev/null; then
    echo -e "${RED}airmon-ng not found. Please install aircrack-ng package.${NC}"
    exit 1
fi

# Check current mode
CURRENT_MODE=$(iw dev "$INTERFACE" info | grep type | awk '{print $2}')
if [ "$CURRENT_MODE" == "monitor" ]; then
    echo -e "${YELLOW}Interface $INTERFACE is already in monitor mode.${NC}"
    MONITOR_INTERFACE="$INTERFACE"
else
    echo -e "${GREEN}Stopping network services...${NC}"
    airmon-ng check kill

    echo -e "${GREEN}Setting $INTERFACE down...${NC}"
    ip link set "$INTERFACE" down

    echo -e "${GREEN}Enabling monitor mode on $INTERFACE...${NC}"
    airmon-ng start "$INTERFACE"

    # Get the new monitor mode interface name
    MONITOR_INTERFACE=$(iw dev | grep -B 1 "type monitor" | grep Interface | awk '{print $2}')
    if [ -z "$MONITOR_INTERFACE" ]; then
        echo -e "${RED}Failed to enable monitor mode${NC}"
        exit 1
    fi
    echo -e "${GREEN}Monitor mode enabled on $MONITOR_INTERFACE${NC}"
fi

# Check if airodump-ng is available
if ! command -v airodump-ng &> /dev/null; then
    echo -e "${YELLOW}airodump-ng not found. Monitor mode enabled but packet capture unavailable.${NC}"
    echo -e "${GREEN}You can use other tools with interface: $MONITOR_INTERFACE${NC}"
    exit 0
fi

echo -e "${GREEN}Starting airodump-ng on $MONITOR_INTERFACE...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop capturing${NC}"
airodump-ng "$MONITOR_INTERFACE"
