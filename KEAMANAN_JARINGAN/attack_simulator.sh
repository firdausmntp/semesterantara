#!/bin/bash
# File: attack_simulator.sh

TARGET_IP="127.0.0.1"  # Change to target IP
LOCAL_NET=$(ip route | grep $(ip route | grep default | awk '{print $5}' | head -1) | grep -E '192\.168|10\.|172\.' | head -1 | awk '{print $1}' | cut -d'/' -f1)

show_menu() {
    echo "=== ATTACK SIMULATOR & TESTER ==="
    echo "Current target: $TARGET_IP"
    echo "1. Port Scan Attack (Nmap)"
    echo "2. SSH Brute Force Simulation"
    echo "3. ICMP Flood Attack"
    echo "4. Custom Port Scan"
    echo "5. Change Target IP"
    echo "6. Generate Normal Traffic"
    echo "7. Exit"
    echo "================================="
}

port_scan_attack() {
    echo "🎯 Performing port scan on $TARGET_IP..."
    echo "This will trigger IDS port scan detection rules"
    
    # Fast scan
    nmap -sS -F $TARGET_IP
    
    # Aggressive scan
    nmap -sS -p 1-1000 $TARGET_IP
    
    echo "✅ Port scan completed!"
}

ssh_brute_force() {
    echo "🔐 Simulating SSH brute force on $TARGET_IP..."
    echo "This will trigger SSH brute force detection rules"
    
    # Multiple connection attempts
    for i in {1..10}; do
        echo "Attempt $i: Connecting to SSH..."
        timeout 2 ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no invalid_user@$TARGET_IP 2>/dev/null
        sleep 1
    done
    
    echo "✅ SSH brute force simulation completed!"
}

icmp_flood() {
    echo "🌊 Performing ICMP flood on $TARGET_IP..."
    echo "This will trigger ICMP flood detection rules"
    
    # Send rapid ICMP packets
    ping -c 50 -i 0.1 $TARGET_IP
    
    echo "✅ ICMP flood completed!"
}

custom_port_scan() {
    echo "🔍 Custom port scan options:"
    echo "1. SYN Stealth Scan"
    echo "2. Connect Scan"
    echo "3. UDP Scan"
    echo "4. OS Detection"
    
    read -p "Choose scan type (1-4): " scan_type
    
    case $scan_type in
        1) nmap -sS $TARGET_IP ;;
        2) nmap -sT $TARGET_IP ;;
        3) nmap -sU $TARGET_IP ;;
        4) nmap -O $TARGET_IP ;;
        *) echo "Invalid option" ;;
    esac
}

change_target() {
    echo "Current target: $TARGET_IP"
    echo "Suggested targets:"
    echo "1. localhost (127.0.0.1)"
    echo "2. Local network gateway"
    echo "3. Custom IP"
    
    read -p "Choose option or enter custom IP: " new_target
    
    case $new_target in
        1) TARGET_IP="127.0.0.1" ;;
        2) TARGET_IP=$(ip route | grep default | awk '{print $3}') ;;
        3) 
            read -p "Enter custom IP: " custom_ip
            TARGET_IP=$custom_ip
            ;;
        *) 
            if [[ $new_target =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                TARGET_IP=$new_target
            else
                echo "Invalid IP format"
            fi
            ;;
    esac
    
    echo "✅ Target changed to: $TARGET_IP"
}

generate_normal_traffic() {
    echo "📊 Generating normal traffic..."
    
    # Normal web requests
    curl -s http://www.google.com > /dev/null
    curl -s http://www.github.com > /dev/null
    
    # DNS queries
    nslookup google.com > /dev/null
    nslookup github.com > /dev/null
    
    # Ping tests
    ping -c 3 8.8.8.8 > /dev/null
    
    echo "✅ Normal traffic generated!"
}

# Main menu loop
while true; do
    show_menu
    read -p "Choose option (1-7): " choice
    
    case $choice in
        1) port_scan_attack ;;
        2) ssh_brute_force ;;
        3) icmp_flood ;;
        4) custom_port_scan ;;
        5) change_target ;;
        6) generate_normal_traffic ;;
        7) echo "👋 Goodbye!"; exit 0 ;;
        *) echo "❌ Invalid option" ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
    clear
done