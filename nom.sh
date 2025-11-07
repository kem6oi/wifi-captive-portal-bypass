#!/bin/bash
# Managed Mode Script
# Purpose: Restores interface to managed (normal) mode from monitor mode

# run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use sudo."
   exit 1
fi


RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Use INTERFACE from environment, fallback to default if not set
INTERFACE=${INTERFACE:-"wlp3s0b1"}


if ! iw dev "$INTERFACE" info > /dev/null 2>&1; then
    echo -e "${RED}Interface $INTERFACE not found. Please check your wireless interface name.${NC}"
    exit 1
fi


echo -e "${GREEN}Setting $INTERFACE down...${NC}"
ip link set "$INTERFACE" down


echo -e "${GREEN}Switching $INTERFACE to managed mode...${NC}"
iw dev "$INTERFACE" set type managed


echo -e "${GREEN}Bringing $INTERFACE up...${NC}"
ip link set "$INTERFACE" up


echo -e "${GREEN}Restarting network services...${NC}"
service NetworkManager restart


echo -e "${GREEN}Current mode:${NC}"
iw dev "$INTERFACE" info | grep type

echo -e "${GREEN}Managed mode restored on $INTERFACE.${NC}"
