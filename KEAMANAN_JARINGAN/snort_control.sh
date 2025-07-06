#!/bin/bash
# File: snort_control.sh

SNORT_PID_FILE="/var/run/snort.pid"
SNORT_CONFIG="/etc/snort/snort.conf"
SNORT_LOG_DIR="/var/log/snort"

# Get network interface with improved detection and user input if needed
get_interface() {
    # First try the default detection method
    local detected_interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    # If we couldn't detect, or to verify the interface, show all interfaces
    if [[ "$detected_interface" == "" ]]; then
        echo "Could not automatically detect interface."
        echo "Available network interfaces:"
        ip -o link show | awk -F': ' '{print $2}'
        read -p "Enter interface name to use: " selected_interface
        echo $selected_interface
    else
        echo $detected_interface
    fi
}

INTERFACE=$(get_interface)

show_menu() {
    echo "=== SNORT CONTROLLER ==="
    echo "1. Start Snort"
    echo "2. Stop Snort"
    echo "3. Restart Snort"
    echo "4. Check Status"
    echo "5. View Real-time Alerts"
    echo "6. View Alert Log"
    echo "7. Test Rules"
    echo "8. Change Network Interface (current: $INTERFACE)"
    echo "9. Exit"
    echo "======================="
}

start_snort() {
    if [ -f "$SNORT_PID_FILE" ]; then
        echo "⚠️  Snort is already running (PID: $(cat $SNORT_PID_FILE))"
        return
    fi
    
    echo "🚀 Starting Snort..."
    echo "Using interface: $INTERFACE"
    
    sudo snort -A fast -b -d -D -i $INTERFACE -u snort -g snort -c $SNORT_CONFIG -l $SNORT_LOG_DIR --pid-path /var/run --create-pidfile
    
    if [ $? -eq 0 ]; then
        echo "✅ Snort started successfully!"
        echo "Interface: $INTERFACE"
        echo "Logs: $SNORT_LOG_DIR"
    else
        echo "❌ Failed to start Snort"
        echo "You may need to manually select a different interface."
        echo "Available interfaces:"
        ip -o link show | awk -F': ' '{print $2}'
    fi
}

stop_snort() {
    if [ -f "$SNORT_PID_FILE" ]; then
        echo "🛑 Stopping Snort..."
        sudo kill $(cat $SNORT_PID_FILE)
        sudo rm -f $SNORT_PID_FILE
        echo "✅ Snort stopped!"
    else
        echo "⚠️  Snort is not running"
    fi
}

check_status() {
    if [ -f "$SNORT_PID_FILE" ]; then
        PID=$(cat $SNORT_PID_FILE)
        if ps -p $PID > /dev/null 2>&1; then
            echo "✅ Snort is running (PID: $PID)"
            echo "Interface: $INTERFACE"
            echo "Config: $SNORT_CONFIG"
            echo "Logs: $SNORT_LOG_DIR"
        else
            echo "❌ Snort PID file exists but process is not running"
            sudo rm -f $SNORT_PID_FILE
        fi
    else
        echo "❌ Snort is not running"
    fi
}

view_realtime_alerts() {
    echo "📊 Real-time alerts (Press Ctrl+C to stop):"
    sudo tail -f $SNORT_LOG_DIR/alert 2>/dev/null || echo "No alerts file found"
}

view_alert_log() {
    echo "📋 Recent alerts:"
    sudo tail -20 $SNORT_LOG_DIR/alert 2>/dev/null || echo "No alerts file found"
}

test_rules() {
    echo "🧪 Testing Snort rules..."
    sudo snort -T -c $SNORT_CONFIG
}

# Function to change the interface
change_interface() {
    echo "Available network interfaces:"
    ip -o link show | awk -F': ' '{print $2}'
    read -p "Enter interface name to use: " new_interface
    if [[ "$new_interface" != "" ]]; then
        INTERFACE=$new_interface
        echo "✅ Interface changed to: $INTERFACE"
    else
        echo "⚠️ Interface unchanged"
    fi
}

# Main menu loop
while true; do
    show_menu
    read -p "Choose option (1-9): " choice
    
    case $choice in
        1) start_snort ;;
        2) stop_snort ;;
        3) stop_snort; sleep 2; start_snort ;;
        4) check_status ;;
        5) view_realtime_alerts ;;
        6) view_alert_log ;;
        7) test_rules ;;
        8) change_interface ;;
        9) echo "👋 Goodbye!"; exit 0 ;;
        *) echo "❌ Invalid option" ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
    clear
done