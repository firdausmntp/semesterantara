#!/bin/bash
# File: suricata_control.sh

SURICATA_CONFIG="/etc/suricata/suricata.yaml"
SURICATA_LOG_DIR="/var/log/suricata"
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

show_menu() {
    echo "=== SURICATA CONTROLLER ==="
    echo "1. Start Suricata"
    echo "2. Stop Suricata"
    echo "3. Restart Suricata"
    echo "4. Check Status"
    echo "5. View Real-time Alerts"
    echo "6. View Alert Log"
    echo "7. View JSON Events"
    echo "8. Test Rules"
    echo "9. Exit"
    echo "=========================="
}

start_suricata() {
    if pgrep suricata > /dev/null; then
        echo "⚠️  Suricata is already running"
        return
    fi
    
    echo "🚀 Starting Suricata..."
    sudo suricata -c $SURICATA_CONFIG -i $INTERFACE -D
    
    if [ $? -eq 0 ]; then
        echo "✅ Suricata started successfully!"
        echo "Interface: $INTERFACE"
        echo "Logs: $SURICATA_LOG_DIR"
    else
        echo "❌ Failed to start Suricata"
    fi
}

stop_suricata() {
    if pgrep suricata > /dev/null; then
        echo "🛑 Stopping Suricata..."
        sudo pkill suricata
        sleep 2
        echo "✅ Suricata stopped!"
    else
        echo "⚠️  Suricata is not running"
    fi
}

check_status() {
    if pgrep suricata > /dev/null; then
        PID=$(pgrep suricata)
        echo "✅ Suricata is running (PID: $PID)"
        echo "Interface: $INTERFACE"
        echo "Config: $SURICATA_CONFIG"
        echo "Logs: $SURICATA_LOG_DIR"
    else
        echo "❌ Suricata is not running"
    fi
}

view_realtime_alerts() {
    echo "📊 Real-time alerts (Press Ctrl+C to stop):"
    sudo tail -f $SURICATA_LOG_DIR/fast.log 2>/dev/null || echo "No alerts file found"
}

view_alert_log() {
    echo "📋 Recent alerts:"
    sudo tail -20 $SURICATA_LOG_DIR/fast.log 2>/dev/null || echo "No alerts file found"
}

view_json_events() {
    echo "📋 Recent JSON events:"
    sudo tail -10 $SURICATA_LOG_DIR/eve.json 2>/dev/null | jq '.' || echo "No JSON events file found"
}

test_rules() {
    echo "🧪 Testing Suricata rules..."
    sudo suricata -T -c $SURICATA_CONFIG
}

# Main menu loop
while true; do
    show_menu
    read -p "Choose option (1-9): " choice
    
    case $choice in
        1) start_suricata ;;
        2) stop_suricata ;;
        3) stop_suricata; sleep 2; start_suricata ;;
        4) check_status ;;
        5) view_realtime_alerts ;;
        6) view_alert_log ;;
        7) view_json_events ;;
        8) test_rules ;;
        9) echo "👋 Goodbye!"; exit 0 ;;
        *) echo "❌ Invalid option" ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
    clear
done