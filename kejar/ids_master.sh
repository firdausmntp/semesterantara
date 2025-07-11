#!/bin/bash
# File: ids_master.sh

show_menu() {
    echo "=== IDS MASTER CONTROL ==="
    echo "1. Setup Snort"
    echo "2. Setup Suricata"
    echo "3. Control Snort"
    echo "4. Control Suricata"
    echo "5. Attack Simulator"
    echo "6. Log Analyzer"
    echo "7. System Status"
    echo "8. Install Dependencies"
    echo "9. Exit"
    echo "=========================="
}

system_status() {
    echo "🖥️  SYSTEM STATUS"
    echo "================"
    
    # Network interface
    echo "Network Interface: $(ip route | grep default | awk '{print $5}' | head -1)"
    echo "IP Address: $(ip route get 8.8.8.8 | grep -oP 'src \K[^ ]+')"
    echo
    
    # IDS Status
    echo "IDS STATUS:"
    if pgrep snort > /dev/null; then
        echo "✅ Snort: Running (PID: $(pgrep snort))"
    else
        echo "❌ Snort: Not running"
    fi
    
    if pgrep suricata > /dev/null; then
        echo "✅ Suricata: Running (PID: $(pgrep suricata))"
    else
        echo "❌ Suricata: Not running"
    fi
    echo
    
    # Log files
    echo "LOG FILES:"
    if [ -f "/var/log/snort/alert" ]; then
        echo "📄 Snort alerts: $(wc -l < /var/log/snort/alert) lines"
    fi
    if [ -f "/var/log/suricata/fast.log" ]; then
        echo "📄 Suricata alerts: $(wc -l < /var/log/suricata/fast.log) lines"
    fi
    echo
    
    # Disk usage
    echo "DISK USAGE:"
    df -h /var/log | tail -1
}

install_dependencies() {
    echo "📦 INSTALLING DEPENDENCIES"
    echo "=========================="
    
    sudo apt update
    sudo apt install -y curl wget git nmap jq
    
    echo "✅ Dependencies installed!"
}

# Make scripts executable
chmod +x setup_snort.sh setup_suricata.sh snort_control.sh suricata_control.sh attack_simulator.sh ids_analyzer.sh

# Main menu loop
while true; do
    show_menu
    read -p "Choose option (1-9): " choice
    
    case $choice in
        1) ./setup_snort.sh ;;
        2) ./setup_suricata.sh ;;
        3) ./snort_control.sh ;;
        4) ./suricata_control.sh ;;
        5) ./attack_simulator.sh ;;
        6) ./ids_analyzer.sh ;;
        7) system_status ;;
        8) install_dependencies ;;
        9) echo "👋 Goodbye!"; exit 0 ;;
        *) echo "❌ Invalid option" ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
    clear
done