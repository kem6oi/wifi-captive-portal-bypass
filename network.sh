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
NC='\033[0m' # No Color

# Load config
CONFIG_FILE="config.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    INTERFACE="wlp3s0b1"
    echo -e "${YELLOW}Config file $CONFIG_FILE not found. Using default interface: $INTERFACE${NC}"
fi

# Check if required scripts exist
for script in mon.sh nom.sh mac_changer.sh; do
    if [ ! -f "$script" ]; then
        echo -e "${RED}Required script $script not found in the current directory.${NC}"
        exit 1
    fi
    if [ ! -x "$script" ]; then
        echo -e "${RED}Script $script is not executable. Run 'chmod +x $script' to fix.${NC}"
        exit 1
    fi
done

# Check if mac_addresses.txt exists
if [ ! -f "macs.txt" ]; then
    echo -e "${YELLOW}Warning: macs.txt not found. Required for MAC address changing.${NC}"
fi

# Function to check if interface exists
check_interface() {
    if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
        echo -e "${RED}Interface $INTERFACE not found. Please check your network interface name.${NC}"
        exit 1
    fi
}

# Display Vikk banner
echo -e "${GREEN}"
cat << "EOF"
 __      __ _ _    
 \ \    / /(_) |   
  \ \  / /  _| | __
   \ \/ /  | | |/ /
    \  /   | |   < 
     \/    |_|_|\_\
EOF
echo -e "Network Tool by Vikk${NC}"
echo "---------------------------"

# Prompt for network interface
echo -e "${YELLOW}Current default interface: $INTERFACE${NC}"
read -p "Enter your network interface (press Enter to use default): " user_interface
if [ -n "$user_interface" ]; then
    INTERFACE="$user_interface"
fi
check_interface
export INTERFACE

while true; do
    echo -e "\n${GREEN}Select an option:${NC}"
    echo -e "${YELLOW}1. Switch to Monitor Mode${NC}"
    echo -e "${YELLOW}2. Switch to Managed Mode${NC}"
    echo -e "${YELLOW}3. Change MAC Address${NC}"
    echo -e "${YELLOW}4. Exit${NC}"
    read -p "Enter your choice (1-4): " choice

    case $choice in
        1)
            echo -e "${GREEN}Switching to Monitor Mode...${NC}"
            ./mon.sh
            ;;
        2)
            echo -e "${GREEN}Switching to Managed Mode...${NC}"
            ./nom.sh
            ;;
        3)
            echo -e "${GREEN}Changing MAC Address...${NC}"
            ./mac_changer.sh
            ;;
        4)
            echo -e "${GREEN}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter a number between 1 and 4.${NC}"
            ;;
    esac
done