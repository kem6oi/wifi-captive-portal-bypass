#!/bin/bash

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use sudo."
   exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Use INTERFACE from environment, fallback to default if not set
INTERFACE=${INTERFACE:-"wlp3s0b1"}

# Path to the MAC address list file
MAC_LIST="macs.txt"

# Check if interface exists
if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
    echo -e "${RED}Interface $INTERFACE not found. Please check your network interface name.${NC}"
    exit 1
fi

# Check if MAC address list file exists
if [ ! -f "$MAC_LIST" ]; then
    echo -e "${RED}MAC address list file ($MAC_LIST) not found. Please create it with a list of MAC addresses.${NC}"
    exit 1
fi

# Function to change MAC address
change_mac() {
    local mac=$1
    echo -e "${GREEN}Setting $INTERFACE down...${NC}"
    ip link set "$INTERFACE" down
    echo -e "${GREEN}Changing MAC address to $mac...${NC}"
    ip link set "$INTERFACE" address "$mac"
    echo -e "${GREEN}Bringing $INTERFACE up...${NC}"
    ip link set "$INTERFACE" up
}

# Function to check internet connectivity
check_connection() {
    ping -c 1 -W 2 google.com > ping_output.txt 2>/dev/null
    if grep -q "64 bytes" ping_output.txt; then
        echo -e "${GREEN}Connection successful with 64 bytes response.${NC}"
        rm ping_output.txt
        return 0
    else
        echo -e "${YELLOW}No connection detected.${NC}"
        rm ping_output.txt
        return 1
    fi
}

# Read MAC addresses from file and try each one
while IFS= read -r mac; do
    [[ -z "$mac" || "$mac" =~ ^# ]] && continue

    echo -e "${YELLOW}Trying MAC address: $mac${NC}"
    change_mac "$mac"

    sleep 5

    if check_connection; then
        echo -e "${GREEN}Internet connection established with MAC: $mac${NC}"
        echo -e "${GREEN}Current MAC address:${NC}"
        ip link show "$INTERFACE" | grep ether
        exit 0
    else
        echo -e "${YELLOW}Failed to connect with $mac. Trying next address...${NC}"
    fi
done < "$MAC_LIST"

echo -e "${RED}Exhausted all MAC addresses in the list. No connection established.${NC}"
exit 1