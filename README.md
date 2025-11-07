# wifi-captive-portal-bypass
This script is meant to bypass captive portals restricting wifi connections

# Vikk's Wireless Network Tool Suite

A suite of Bash scripts for managing wireless interfaces on Linux, orchestrated by a main script with a colorful interface.

## Scripts
- `network.sh`: Main interface with a "Vikk" banner
- `mon.sh`: Switches to monitor mode
- `nom.sh`: Restores managed mode
- `mac_changer.sh`: Changes MAC address from a list

## Prerequisites
- Linux with wireless capabilities
- Root privileges (sudo)
- Tools: `airmon-ng`, `iw`, `ip`, `ping`, `curl` or `wget`, NetworkManager
- `macs.txt` file (e.g., `00:11:22:33:44:55` per line)

## Installation
1. Clone the repository:
```bash
git clone https://github.com/kem6oi/wifi-captive-portal-bypass.git
```
## Make the script executable
```bash
chmod +x *.sh
```
## Usage
```bash
sudo ./network.sh
```

## Configuration
Edit ```config.conf``` 
INTERFACE="wlan0"

## Files

    config.conf: Default settings
    macs.txt: List of MAC addresses

## Features

### Captive Portal Detection
The tool includes sophisticated captive portal detection that:
- Tests multiple connectivity endpoints (Google, Apple, Microsoft)
- Distinguishes between network access and actual internet access
- Provides clear feedback on bypass success vs captive portal presence
- Uses industry-standard detection methods employed by major operating systems

When testing MAC addresses, the tool will:
1. Check basic network connectivity (ping)
2. Test HTTP endpoints to detect captive portal redirects
3. Verify full internet access before declaring success

## Notes

    Requires all scripts in the same directory
    May disrupt connectivity
    Interface must support mode switching and MAC spoofing
    Captive portal detection requires curl or wget
## DISCLAIMER 
THIS SCRIPT SHOULD ONLY BE USED IN NETWORKS YOU OWN OR HAVE EXCLUSIVE PERMISSION TO. 
