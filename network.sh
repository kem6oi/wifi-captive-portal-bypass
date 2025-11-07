#!/bin/bash
# WiFi Network Tool Suite
# Main script providing interface to monitor mode, managed mode, and MAC changing tools

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use sudo."
   exit 1
fi


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    local required_commands=("ip" "iw" "ping")

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    # Check for HTTP client (required for captive portal detection)
    if ! command -v "curl" &> /dev/null && ! command -v "wget" &> /dev/null; then
        missing_deps+=("curl or wget")
    fi

    # Check for optional but recommended tools
    if ! command -v "airmon-ng" &> /dev/null; then
        echo -e "${YELLOW}Warning: airmon-ng not found. Monitor mode functionality will be limited.${NC}"
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required dependencies: ${missing_deps[*]}${NC}"
        echo -e "${YELLOW}Please install the missing packages and try again.${NC}"
        exit 1
    fi
}

# Run dependency check
check_dependencies

CONFIG_FILE="config.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    INTERFACE="wlp3s0b1"
    echo -e "${YELLOW}Config file $CONFIG_FILE not found. Using default interface: $INTERFACE${NC}"
fi


for script in mon.sh nom.sh mac_changer.sh mac_scanner.sh; do
    if [ ! -f "$script" ]; then
        echo -e "${RED}Required script $script not found in the current directory.${NC}"
        exit 1
    fi
    if [ ! -x "$script" ]; then
        echo -e "${RED}Script $script is not executable. Run 'chmod +x $script' to fix.${NC}"
        exit 1
    fi
done

if [ ! -f "macs.txt" ]; then
    echo -e "${YELLOW}Warning: macs.txt not found. Required for MAC address changing.${NC}"
fi

# check if interface exists
check_interface() {
    if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
        echo -e "${RED}Interface $INTERFACE not found. Please check your network interface name.${NC}"
        exit 1
    fi
}

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
    echo -e "${YELLOW}4. Scan & Test Network MACs${NC}"
    echo -e "${YELLOW}5. Exit${NC}"
    read -p "Enter your choice (1-5): " choice

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
            echo -e "${GREEN}Scanning Network for MAC Addresses...${NC}"
            ./mac_scanner.sh
            ;;
        5)
            echo -e "${GREEN}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter a number between 1 and 5.${NC}"
            ;;
    esac
done
