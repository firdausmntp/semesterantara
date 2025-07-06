#!/bin/bash
# File: suricata_control.sh

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_functions.sh"

SURICATA_CONFIG="/etc/suricata/suricata.yaml"
SURICATA_LOG_DIR="/var/log/suricata"

# Enhanced interface detection with validation
get_interface() {
    local detected_interface=$(get_default_interface)
    
    # Validate the detected interface
    if [[ -n "$detected_interface" && "$detected_interface" != "lo" ]]; then
        # Check if interface is up
        local interface_status=$(get_available_interfaces | grep "^$detected_interface:" | cut -d: -f2)
        if [[ "$interface_status" == "UP" ]]; then
            echo "$detected_interface"
            return 0
        fi
    fi
    
    # Fallback to manual selection
    log_warning "Could not automatically detect a suitable interface."
    echo "Available network interfaces:"
    echo "Interface  Status"
    echo "--------------------"
    get_available_interfaces | while IFS=: read -r iface status; do
        echo "  $iface      $status"
    done
    echo
    
    while true; do
        read -p "Enter interface name to use: " selected_interface
        if [[ -n "$selected_interface" ]]; then
            if ip link show "$selected_interface" >/dev/null 2>&1; then
                echo "$selected_interface"
                return 0
            else
                log_error "Interface '$selected_interface' does not exist. Please try again."
            fi
        else
            log_error "Please enter a valid interface name."
        fi
    done
}

# Initialize interface
INTERFACE=$(get_interface)
log_info "Using interface: $INTERFACE"

show_menu() {
    echo
    echo "=== SURICATA IDS CONTROLLER ==="
    echo "1. Start Suricata"
    echo "2. Stop Suricata"
    echo "3. Restart Suricata"
    echo "4. Check Status"
    echo "5. View Real-time Alerts"
    echo "6. View Alert Log"
    echo "7. View JSON Events"
    echo "8. Test Configuration"
    echo "9. Change Network Interface (current: $INTERFACE)"
    echo "10. Exit"
    echo "==============================="
}

start_suricata() {
    # Check if Suricata is already running
    if pgrep suricata >/dev/null 2>&1; then
        local pid=$(pgrep suricata)
        log_warning "Suricata is already running (PID: $pid)"
        return 1
    fi
    
    # Validate configuration file exists
    if [[ ! -f "$SURICATA_CONFIG" ]]; then
        log_error "Suricata configuration file not found: $SURICATA_CONFIG"
        log_info "Please run setup_suricata.sh first to create the configuration."
        return 1
    fi
    
    # Test configuration
    log_info "Testing Suricata configuration..."
    if ! sudo suricata -T -c "$SURICATA_CONFIG" >/dev/null 2>&1; then
        log_error "Suricata configuration test failed!"
        log_info "Run 'sudo suricata -T -c $SURICATA_CONFIG' to see details"
        return 1
    fi
    log_success "Configuration test passed"
    
    # Check if interface exists and is up
    if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
        log_error "Network interface '$INTERFACE' does not exist!"
        log_info "Available interfaces:"
        get_available_interfaces | while IFS=: read -r iface status; do
            echo "  $iface ($status)"
        done
        return 1
    fi
    
    # Check if log directory exists
    if [[ ! -d "$SURICATA_LOG_DIR" ]]; then
        log_info "Creating log directory: $SURICATA_LOG_DIR"
        create_directory "$SURICATA_LOG_DIR" "suricata" "suricata" "755"
    fi
    
    log_info "🚀 Starting Suricata IDS..."
    log_info "Interface: $INTERFACE"
    log_info "Configuration: $SURICATA_CONFIG"
    log_info "Log Directory: $SURICATA_LOG_DIR"
    
    # Start Suricata with proper error handling
    local suricata_cmd="sudo suricata -c $SURICATA_CONFIG -i $INTERFACE -D"
    
    if $suricata_cmd; then
        # Wait a moment for startup
        sleep 3
        
        # Verify it's actually running
        if pgrep suricata >/dev/null 2>&1; then
            local pid=$(pgrep suricata)
            log_success "✅ Suricata started successfully!"
            log_info "Process ID: $pid"
            log_info "Fast log: $SURICATA_LOG_DIR/fast.log"
            log_info "JSON log: $SURICATA_LOG_DIR/eve.json"
            log_info "Main log: $SURICATA_LOG_DIR/suricata.log"
        else
            log_error "Suricata failed to start properly"
            return 1
        fi
    else
        log_error "❌ Failed to start Suricata"
        log_info "Check the system logs for more details: sudo journalctl -u suricata"
        log_info "Available interfaces:"
        get_available_interfaces | while IFS=: read -r iface status; do
            echo "  $iface ($status)"
        done
        return 1
    fi
}

stop_suricata() {
    if pgrep suricata >/dev/null 2>&1; then
        log_info "🛑 Stopping Suricata..."
        local pid=$(pgrep suricata)
        
        if sudo kill "$pid"; then
            # Wait for graceful shutdown
            local count=0
            while [[ $count -lt 10 ]] && pgrep suricata >/dev/null 2>&1; do
                sleep 1
                ((count++))
            done
            
            # Force kill if still running
            if pgrep suricata >/dev/null 2>&1; then
                log_warning "Graceful shutdown failed, forcing termination..."
                sudo pkill -9 suricata
            fi
            
            log_success "✅ Suricata stopped successfully!"
        else
            log_error "Failed to stop Suricata process (PID: $pid)"
            return 1
        fi
    else
        log_warning "⚠️  Suricata is not running"
    fi
}

check_status() {
    log_info "📊 Suricata Status Check"
    echo "========================"
    
    if pgrep suricata >/dev/null 2>&1; then
        local pid=$(pgrep suricata)
        log_success "✅ Suricata is running (PID: $pid)"
        
        # Show runtime information
        echo "Interface: $INTERFACE"
        echo "Configuration: $SURICATA_CONFIG"
        echo "Log Directory: $SURICATA_LOG_DIR"
        echo "Process uptime: $(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ')"
        
        # Show recent activity
        if [[ -f "$SURICATA_LOG_DIR/fast.log" ]]; then
            local alert_count=$(wc -l < "$SURICATA_LOG_DIR/fast.log" 2>/dev/null || echo "0")
            echo "Total alerts: $alert_count"
            
            if [[ $alert_count -gt 0 ]]; then
                echo "Recent alerts (last 3):"
                tail -3 "$SURICATA_LOG_DIR/fast.log" 2>/dev/null | while read -r line; do
                    echo "  $line"
                done
            fi
        else
            echo "Fast log: Not created yet"
        fi
        
        # Check log file sizes
        if [[ -f "$SURICATA_LOG_DIR/eve.json" ]]; then
            local json_size=$(du -h "$SURICATA_LOG_DIR/eve.json" 2>/dev/null | cut -f1)
            echo "JSON log size: $json_size"
        fi
        
        if [[ -f "$SURICATA_LOG_DIR/suricata.log" ]]; then
            local main_log_size=$(du -h "$SURICATA_LOG_DIR/suricata.log" 2>/dev/null | cut -f1)
            echo "Main log size: $main_log_size"
        fi
        
    else
        log_error "❌ Suricata is not running"
        
        # Check for recent logs that might indicate why it stopped
        if [[ -f "$SURICATA_LOG_DIR/fast.log" ]]; then
            local last_alert=$(tail -1 "$SURICATA_LOG_DIR/fast.log" 2>/dev/null)
            if [[ -n "$last_alert" ]]; then
                echo "Last alert: $last_alert"
            fi
        fi
        
        if [[ -f "$SURICATA_LOG_DIR/suricata.log" ]]; then
            echo "Recent log entries:"
            tail -3 "$SURICATA_LOG_DIR/suricata.log" 2>/dev/null | while read -r line; do
                echo "  $line"
            done
        fi
    fi
}

view_realtime_alerts() {
    log_info "📊 Real-time alerts (Press Ctrl+C to stop)"
    echo "=========================================="
    
    if [[ ! -f "$SURICATA_LOG_DIR/fast.log" ]]; then
        log_warning "Fast log file not found: $SURICATA_LOG_DIR/fast.log"
        log_info "Make sure Suricata is running and generating alerts"
        return 1
    fi
    
    # Show existing alerts first
    if [[ -s "$SURICATA_LOG_DIR/fast.log" ]]; then
        log_info "Recent alerts:"
        tail -5 "$SURICATA_LOG_DIR/fast.log"
        echo "----------------------------------------"
        log_info "Watching for new alerts..."
    fi
    
    sudo tail -f "$SURICATA_LOG_DIR/fast.log" 2>/dev/null
}

view_alert_log() {
    log_info "📋 Recent Suricata Alerts"
    echo "========================="
    
    if [[ ! -f "$SURICATA_LOG_DIR/fast.log" ]]; then
        log_warning "Fast log file not found: $SURICATA_LOG_DIR/fast.log"
        log_info "No alerts have been generated yet."
        return 1
    fi
    
    local total_alerts=$(wc -l < "$SURICATA_LOG_DIR/fast.log" 2>/dev/null || echo "0")
    log_info "Total alerts: $total_alerts"
    
    if [[ $total_alerts -gt 0 ]]; then
        echo
        log_info "Last 20 alerts:"
        sudo tail -20 "$SURICATA_LOG_DIR/fast.log" | nl
    else
        log_info "No alerts found in fast log file."
    fi
}

view_json_events() {
    log_info "📋 Recent JSON Events"
    echo "===================="
    
    if [[ ! -f "$SURICATA_LOG_DIR/eve.json" ]]; then
        log_warning "JSON events file not found: $SURICATA_LOG_DIR/eve.json"
        log_info "Make sure Suricata is running and eve-log is enabled"
        return 1
    fi
    
    if command_exists jq; then
        log_info "Last 10 events (formatted):"
        sudo tail -10 "$SURICATA_LOG_DIR/eve.json" | jq '.'
    else
        log_info "Last 10 events (raw JSON):"
        sudo tail -10 "$SURICATA_LOG_DIR/eve.json"
        echo
        log_info "Install 'jq' for better JSON formatting: sudo apt install jq"
    fi
}

test_rules() {
    log_info "🧪 Testing Suricata Configuration"
    echo "================================="
    
    if [[ ! -f "$SURICATA_CONFIG" ]]; then
        log_error "Configuration file not found: $SURICATA_CONFIG"
        return 1
    fi
    
    log_info "Running configuration test..."
    if sudo suricata -T -c "$SURICATA_CONFIG"; then
        log_success "✅ Configuration test passed!"
    else
        log_error "❌ Configuration test failed!"
        log_info "Check the error messages above for details."
        return 1
    fi
}

# Enhanced interface change function
change_interface() {
    log_info "🔧 Change Network Interface"
    echo "============================"
    
    echo "Current interface: $INTERFACE"
    echo
    echo "Available network interfaces:"
    echo "Interface  Status"
    echo "--------------------"
    get_available_interfaces | while IFS=: read -r iface status; do
        if [[ "$iface" == "$INTERFACE" ]]; then
            echo "* $iface      $status (current)"
        else
            echo "  $iface      $status"
        fi
    done
    echo
    
    while true; do
        read -p "Enter new interface name (or 'cancel' to abort): " new_interface
        
        if [[ "$new_interface" == "cancel" ]]; then
            log_info "Interface change cancelled"
            return 0
        fi
        
        if [[ -n "$new_interface" ]]; then
            if ip link show "$new_interface" >/dev/null 2>&1; then
                # Check if Suricata is running and stop it
                if pgrep suricata >/dev/null 2>&1; then
                    if confirm_action "Suricata is running. Stop it to change interface?" "y"; then
                        stop_suricata
                    else
                        log_info "Interface change cancelled"
                        return 0
                    fi
                fi
                
                INTERFACE="$new_interface"
                log_success "✅ Interface changed to: $INTERFACE"
                log_info "You can now start Suricata with the new interface"
                return 0
            else
                log_error "Interface '$new_interface' does not exist. Please try again."
            fi
        else
            log_error "Please enter a valid interface name or 'cancel'."
        fi
    done
}

# Main menu loop with enhanced error handling
while true; do
    show_menu
    read -p "Choose option (1-10): " choice
    
    case $choice in
        1) 
            start_suricata
            ;;
        2) 
            stop_suricata
            ;;
        3) 
            log_info "Restarting Suricata..."
            stop_suricata
            sleep 2
            start_suricata
            ;;
        4) 
            check_status
            ;;
        5) 
            view_realtime_alerts
            ;;
        6) 
            view_alert_log
            ;;
        7) 
            view_json_events
            ;;
        8) 
            test_rules
            ;;
        9) 
            change_interface
            ;;
        10) 
            log_info "👋 Goodbye!"
            exit 0
            ;;
        *) 
            log_error "❌ Invalid option. Please choose 1-10."
            ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
    clear
done