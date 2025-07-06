#!/bin/bash
# File: setup_snort.sh

echo "=== SNORT AUTO INSTALLER & CONFIGURATOR ==="
echo "Setting up Snort IDS..."

# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y build-essential libpcap-dev libpcre3-dev libdumbnet-dev bison flex zlib1g-dev liblzma-dev openssl libssl-dev

# Install Snort
sudo apt install -y snort

# Get network interface
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
LOCAL_NET=$(ip route | grep $INTERFACE | grep -E '192\.168|10\.|172\.' | head -1 | awk '{print $1}')

echo "Detected Interface: $INTERFACE"
echo "Detected Local Network: $LOCAL_NET"

# Backup original config
sudo cp /etc/snort/snort.conf /etc/snort/snort.conf.backup

# Configure Snort
sudo tee /etc/snort/snort.conf > /dev/null <<EOF
# Basic Snort Configuration
var HOME_NET $LOCAL_NET
var EXTERNAL_NET !\$HOME_NET
var RULE_PATH /etc/snort/rules
var SO_RULE_PATH /etc/snort/so_rules
var PREPROC_RULE_PATH /etc/snort/preproc_rules

# Output configuration
output alert_fast: /var/log/snort/alert
output log_tcpdump: /var/log/snort/snort.log

# Include rules
include \$RULE_PATH/local.rules
include \$RULE_PATH/community.rules
EOF

# Create custom rules
sudo mkdir -p /etc/snort/rules
sudo tee /etc/snort/rules/local.rules > /dev/null <<EOF
# Port Scan Detection
alert tcp any any -> \$HOME_NET any (msg:"Possible Port Scan"; flags:S; threshold:type both, track by_src, count 5, seconds 60; sid:1000001; rev:1;)

# SSH Brute Force Detection
alert tcp any any -> \$HOME_NET 22 (msg:"SSH Brute Force Attempt"; flags:S; threshold:type both, track by_src, count 5, seconds 60; sid:1000002; rev:1;)

# Failed Login Detection (Generic)
alert tcp any any -> \$HOME_NET any (msg:"Multiple Failed Login Attempts"; content:"failed"; threshold:type both, track by_src, count 3, seconds 30; sid:1000003; rev:1;)

# ICMP Flood Detection
alert icmp any any -> \$HOME_NET any (msg:"ICMP Flood Detected"; threshold:type both, track by_src, count 10, seconds 5; sid:1000004; rev:1;)
EOF

# Create log directory
sudo mkdir -p /var/log/snort
sudo chmod 755 /var/log/snort

# Create service script
sudo tee /etc/systemd/system/snort.service > /dev/null <<EOF
[Unit]
Description=Snort IDS
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/snort -A fast -b -d -D -i $INTERFACE -u snort -g snort -c /etc/snort/snort.conf -l /var/log/snort
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Create snort user
sudo useradd -r -s /bin/false snort
sudo chown -R snort:snort /var/log/snort

echo "✅ Snort installation and configuration completed!"
echo "Interface: $INTERFACE"
echo "Home Network: $LOCAL_NET"
echo "Log Directory: /var/log/snort"