#!/bin/bash
# MAC Address Changer Script
# Purpose: Cycles through MAC addresses to bypass captive portal restrictions
# Note: Automatically restores original MAC if no connection is found

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

# Path to the MAC address list file
MAC_LIST="macs.txt"


if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
    echo -e "${RED}Interface $INTERFACE not found. Please check your network interface name.${NC}"
    exit 1
fi


if [ ! -f "$MAC_LIST" ]; then
    echo -e "${RED}MAC address list file ($MAC_LIST) not found. Please create it with a list of MAC addresses.${NC}"
    exit 1
fi

# Save original MAC address
ORIGINAL_MAC=$(ip link show "$INTERFACE" | grep ether | awk '{print $2}')
echo -e "${YELLOW}Original MAC address: $ORIGINAL_MAC${NC}"

# Cleanup function to restore original MAC
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    if [ -n "$ORIGINAL_MAC" ]; then
        echo -e "${GREEN}Restoring original MAC address: $ORIGINAL_MAC${NC}"
        ip link set "$INTERFACE" down
        ip link set "$INTERFACE" address "$ORIGINAL_MAC"
        ip link set "$INTERFACE" up
    fi
    echo -e "${GREEN}Cleanup complete.${NC}"
    exit 0
}

# Set up trap to catch signals
trap cleanup SIGINT SIGTERM EXIT

# Check if curl or wget is available
if command -v curl &> /dev/null; then
    HTTP_CLIENT="curl"
elif command -v wget &> /dev/null; then
    HTTP_CLIENT="wget"
else
    echo -e "${RED}Error: Neither curl nor wget found. Please install one of them.${NC}"
    exit 1
fi

# Detect if a captive portal is present
detect_captive_portal() {
    local portal_detected=false

    echo -e "${YELLOW}Testing for captive portal...${NC}"

    # Test Google's connectivity check (expects 204 No Content)
    if [ "$HTTP_CLIENT" = "curl" ]; then
        local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://connectivitycheck.gstatic.com/generate_204 2>/dev/null)
        if [ "$response" = "204" ]; then
            echo -e "${GREEN}✓ Google connectivity check passed (204)${NC}"
            return 0
        else
            echo -e "${YELLOW}✗ Google connectivity check failed (got $response, expected 204)${NC}"
            portal_detected=true
        fi
    else
        # wget doesn't easily give us status codes, so we'll use curl-style checks with other methods
        if wget -q --spider --timeout=5 http://connectivitycheck.gstatic.com/generate_204 2>/dev/null; then
            echo -e "${GREEN}✓ Connectivity check passed${NC}"
            return 0
        else
            echo -e "${YELLOW}✗ Connectivity check failed${NC}"
            portal_detected=true
        fi
    fi

    # Test Apple's captive portal detection (expects "Success")
    if [ "$HTTP_CLIENT" = "curl" ]; then
        local apple_response=$(curl -s --max-time 5 http://captive.apple.com/hotspot-detect.html 2>/dev/null)
        if echo "$apple_response" | grep -q "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>"; then
            echo -e "${GREEN}✓ Apple connectivity check passed${NC}"
            return 0
        else
            echo -e "${YELLOW}✗ Apple connectivity check failed${NC}"
            portal_detected=true
        fi
    fi

    # Test Microsoft's connectivity test (expects "Microsoft Connect Test")
    if [ "$HTTP_CLIENT" = "curl" ]; then
        local ms_response=$(curl -s --max-time 5 http://www.msftconnecttest.com/connecttest.txt 2>/dev/null)
        if echo "$ms_response" | grep -q "Microsoft Connect Test"; then
            echo -e "${GREEN}✓ Microsoft connectivity check passed${NC}"
            return 0
        else
            echo -e "${YELLOW}✗ Microsoft connectivity check failed${NC}"
            portal_detected=true
        fi
    fi

    if [ "$portal_detected" = true ]; then
        echo -e "${RED}⚠ Captive portal detected - internet access restricted${NC}"
        return 1
    fi

    return 1
}

# Validate MAC address format
validate_mac() {
    local mac=$1
    if [[ $mac =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
        return 0
    else
        return 1
    fi
}

change_mac() {
    local mac=$1
    echo -e "${GREEN}Setting $INTERFACE down...${NC}"
    ip link set "$INTERFACE" down
    echo -e "${GREEN}Changing MAC address to $mac...${NC}"
    ip link set "$INTERFACE" address "$mac"
    echo -e "${GREEN}Bringing $INTERFACE up...${NC}"
    ip link set "$INTERFACE" up
}


check_connection() {
    echo -e "${YELLOW}Testing network connectivity...${NC}"

    # First, check basic network connectivity with ping
    local ping_success=false
    for target in 8.8.8.8 1.1.1.1; do
        if ping -c 1 -W 2 "$target" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Network layer connectivity confirmed (ping to $target)${NC}"
            ping_success=true
            break
        fi
    done

    if [ "$ping_success" = false ]; then
        echo -e "${RED}✗ No network connectivity - cannot reach internet${NC}"
        return 1
    fi

    # Now check if there's a captive portal blocking us
    if detect_captive_portal; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✓ SUCCESS: Full internet access - NO captive portal!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        return 0
    else
        echo -e "${YELLOW}Network accessible but captive portal blocking traffic${NC}"
        return 1
    fi
}


while IFS= read -r mac; do
    [[ -z "$mac" || "$mac" =~ ^# ]] && continue

    # Validate MAC address format
    if ! validate_mac "$mac"; then
        echo -e "${RED}Invalid MAC address format: $mac (skipping)${NC}"
        continue
    fi

    echo -e "${YELLOW}Trying MAC address: $mac${NC}"
    change_mac "$mac"

    sleep 5

    if check_connection; then
        echo -e "${GREEN}Internet connection established with MAC: $mac${NC}"
        echo -e "${GREEN}Current MAC address:${NC}"
        ip link show "$INTERFACE" | grep ether
        # Disable cleanup trap since we want to keep the working MAC
        trap - EXIT
        echo -e "${GREEN}Success! Keeping MAC address: $mac${NC}"
        exit 0
    else
        echo -e "${YELLOW}Failed to connect with $mac. Trying next address...${NC}"
    fi
done < "$MAC_LIST"

echo -e "${RED}Exhausted all MAC addresses in the list. No connection established.${NC}"
# Cleanup will be called by EXIT trap
