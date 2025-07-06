#!/bin/bash
# File: setup_suricata.sh

echo "=== SURICATA AUTO INSTALLER & CONFIGURATOR ==="
echo "Setting up Suricata IDS..."

# Update system
sudo apt update && sudo apt upgrade -y

# Install Suricata
sudo apt install -y suricata

# Get network interface
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
LOCAL_NET=$(ip route | grep $INTERFACE | grep -E '192\.168|10\.|172\.' | head -1 | awk '{print $1}')

echo "Detected Interface: $INTERFACE"
echo "Detected Local Network: $LOCAL_NET"

# Backup original config
sudo cp /etc/suricata/suricata.yaml /etc/suricata/suricata.yaml.backup

# Configure Suricata
sudo tee /etc/suricata/suricata.yaml > /dev/null <<EOF
vars:
  address-groups:
    HOME_NET: "[$LOCAL_NET]"
    EXTERNAL_NET: "![\$HOME_NET]"

af-packet:
  - interface: $INTERFACE
    threads: 1
    defrag: yes

outputs:
  - fast:
      enabled: yes
      filename: /var/log/suricata/fast.log
  - eve-log:
      enabled: yes
      filetype: regular
      filename: /var/log/suricata/eve.json

logging:
  default-log-level: info
  outputs:
    - console:
        enabled: yes
    - file:
        enabled: yes
        filename: /var/log/suricata/suricata.log

rule-files:
  - /etc/suricata/rules/local.rules
  - /etc/suricata/rules/suricata.rules
EOF

# Create custom rules
sudo mkdir -p /etc/suricata/rules
sudo tee /etc/suricata/rules/local.rules > /dev/null <<EOF
# Port Scan Detection
alert tcp any any -> \$HOME_NET any (msg:"Port Scan Detected"; flags:S; threshold:type both, track by_src, count 5, seconds 60; sid:2000001; rev:1;)

# SSH Brute Force Detection
alert tcp any any -> \$HOME_NET 22 (msg:"SSH Brute Force Attack"; flags:S; threshold:type both, track by_src, count 5, seconds 60; sid:2000002; rev:1;)

# Failed Login Detection
alert tcp any any -> \$HOME_NET any (msg:"Multiple Failed Logins"; content:"Authentication failure"; threshold:type both, track by_src, count 3, seconds 30; sid:2000003; rev:1;)

# ICMP Flood Detection
alert icmp any any -> \$HOME_NET any (msg:"ICMP Flood Attack"; threshold:type both, track by_src, count 10, seconds 5; sid:2000004; rev:1;)
EOF

# Create log directory
sudo mkdir -p /var/log/suricata
sudo chmod 755 /var/log/suricata

# Set permissions
sudo chown -R suricata:suricata /var/log/suricata
sudo chown -R suricata:suricata /etc/suricata

echo "✅ Suricata installation and configuration completed!"
echo "Interface: $INTERFACE"
echo "Home Network: $LOCAL_NET"
echo "Log Directory: /var/log/suricata"