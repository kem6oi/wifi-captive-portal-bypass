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
- Tools: `airmon-ng`, `iwconfig`, `ifconfig`, `ip`, `ping`, NetworkManager
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
sudo ./network_tool.sh
```

## Configuration
Edit ```config.conf``` 
INTERFACE="wlan0"

## Files

    config.conf: Default settings
    mac_addresses.txt: List of MAC addresses

## Notes

    Requires all scripts in the same directory
    May disrupt connectivity
    Interface must support mode switching and MAC spoofing
## DISCLAIMER 
THIS SCRIPT SHOULD ONLY BE USED IN NETWORKS YOU OWN OR HAVE EXCLUSIVE PERMISSION TO. 
