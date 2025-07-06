#!/bin/bash
# File: snort_control.sh

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_functions.sh"

SNORT_PID_FILE="/var/run/snort.pid"
SNORT_CONFIG="/etc/snort/snort.conf"
SNORT_LOG_DIR="/var/log/snort"

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
    # Check if Snort is already running
    local status=$(check_service_status "snort" "$SNORT_PID_FILE")
    if [[ "$status" == "running" ]]; then
        local pid=$(cat "$SNORT_PID_FILE" 2>/dev/null)
        log_warning "Snort is already running (PID: $pid)"
        return 1
    fi
    
    # Validate configuration file exists
    if [[ ! -f "$SNORT_CONFIG" ]]; then
        log_error "Snort configuration file not found: $SNORT_CONFIG"
        log_info "Please run setup_snort.sh first to create the configuration."
        return 1
    fi
    
    # Test configuration
    log_info "Testing Snort configuration..."
    if ! sudo snort -T -c "$SNORT_CONFIG" >/dev/null 2>&1; then
        log_error "Snort configuration test failed!"
        log_info "Run 'sudo snort -T -c $SNORT_CONFIG' to see details"
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
    if [[ ! -d "$SNORT_LOG_DIR" ]]; then
        log_info "Creating log directory: $SNORT_LOG_DIR"
        create_directory "$SNORT_LOG_DIR" "snort" "snort" "755"
    fi
    
    log_info "🚀 Starting Snort IDS..."
    log_info "Interface: $INTERFACE"
    log_info "Configuration: $SNORT_CONFIG"
    log_info "Log Directory: $SNORT_LOG_DIR"
    
    # Start Snort with proper error handling
    local snort_cmd="sudo snort -A fast -b -d -D -i $INTERFACE -u snort -g snort -c $SNORT_CONFIG -l $SNORT_LOG_DIR --pid-path /var/run --create-pidfile"
    
    if $snort_cmd; then
        # Wait a moment for startup
        sleep 3
        
        # Verify it's actually running
        local status=$(check_service_status "snort" "$SNORT_PID_FILE")
        if [[ "$status" == "running" ]]; then
            local pid=$(cat "$SNORT_PID_FILE" 2>/dev/null)
            log_success "✅ Snort started successfully!"
            log_info "Process ID: $pid"
            log_info "Alert log: $SNORT_LOG_DIR/alert"
            log_info "Packet log: $SNORT_LOG_DIR/snort.log"
        else
            log_error "Snort failed to start properly (no PID file found)"
            return 1
        fi
    else
        log_error "❌ Failed to start Snort"
        log_info "Check the system logs for more details: sudo journalctl -u snort"
        log_info "Available interfaces:"
        get_available_interfaces | while IFS=: read -r iface status; do
            echo "  $iface ($status)"
        done
        return 1
    fi
}

stop_snort() {
    local status=$(check_service_status "snort" "$SNORT_PID_FILE")
    
    if [[ "$status" == "running" ]]; then
        log_info "🛑 Stopping Snort..."
        local pid=$(cat "$SNORT_PID_FILE" 2>/dev/null)
        
        if [[ -n "$pid" ]]; then
            if sudo kill "$pid"; then
                # Wait for graceful shutdown
                local count=0
                while [[ $count -lt 10 ]] && ps -p "$pid" >/dev/null 2>&1; do
                    sleep 1
                    ((count++))
                done
                
                # Force kill if still running
                if ps -p "$pid" >/dev/null 2>&1; then
                    log_warning "Graceful shutdown failed, forcing termination..."
                    sudo kill -9 "$pid"
                fi
                
                sudo rm -f "$SNORT_PID_FILE"
                log_success "✅ Snort stopped successfully!"
            else
                log_error "Failed to stop Snort process (PID: $pid)"
                return 1
            fi
        fi
    else
        log_warning "⚠️  Snort is not running"
        # Clean up stale PID file if it exists
        if [[ -f "$SNORT_PID_FILE" ]]; then
            sudo rm -f "$SNORT_PID_FILE"
            log_info "Removed stale PID file"
        fi
    fi
}

check_status() {
    log_info "📊 Snort Status Check"
    echo "======================="
    
    local status=$(check_service_status "snort" "$SNORT_PID_FILE")
    
    if [[ "$status" == "running" ]]; then
        local pid=$(cat "$SNORT_PID_FILE" 2>/dev/null)
        log_success "✅ Snort is running (PID: $pid)"
        
        # Show runtime information
        echo "Interface: $INTERFACE"
        echo "Configuration: $SNORT_CONFIG"
        echo "Log Directory: $SNORT_LOG_DIR"
        echo "Process uptime: $(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ')"
        
        # Show recent activity
        if [[ -f "$SNORT_LOG_DIR/alert" ]]; then
            local alert_count=$(wc -l < "$SNORT_LOG_DIR/alert" 2>/dev/null || echo "0")
            echo "Total alerts: $alert_count"
            
            if [[ $alert_count -gt 0 ]]; then
                echo "Recent alerts (last 3):"
                tail -3 "$SNORT_LOG_DIR/alert" 2>/dev/null | while read -r line; do
                    echo "  $line"
                done
            fi
        else
            echo "Alert file: Not created yet"
        fi
        
        # Check log file size
        if [[ -f "$SNORT_LOG_DIR/snort.log" ]]; then
            local log_size=$(du -h "$SNORT_LOG_DIR/snort.log" 2>/dev/null | cut -f1)
            echo "Packet log size: $log_size"
        fi
        
    else
        log_error "❌ Snort is not running"
        
        # Check for recent logs that might indicate why it stopped
        if [[ -f "$SNORT_LOG_DIR/alert" ]]; then
            local last_alert=$(tail -1 "$SNORT_LOG_DIR/alert" 2>/dev/null)
            if [[ -n "$last_alert" ]]; then
                echo "Last alert: $last_alert"
            fi
        fi
    fi
}

view_realtime_alerts() {
    log_info "📊 Real-time alerts (Press Ctrl+C to stop)"
    echo "=========================================="
    
    if [[ ! -f "$SNORT_LOG_DIR/alert" ]]; then
        log_warning "Alert file not found: $SNORT_LOG_DIR/alert"
        log_info "Make sure Snort is running and generating alerts"
        return 1
    fi
    
    # Show existing alerts first
    if [[ -s "$SNORT_LOG_DIR/alert" ]]; then
        log_info "Recent alerts:"
        tail -5 "$SNORT_LOG_DIR/alert"
        echo "----------------------------------------"
        log_info "Watching for new alerts..."
    fi
    
    sudo tail -f "$SNORT_LOG_DIR/alert" 2>/dev/null
}

view_alert_log() {
    log_info "📋 Recent Snort Alerts"
    echo "======================"
    
    if [[ ! -f "$SNORT_LOG_DIR/alert" ]]; then
        log_warning "Alert file not found: $SNORT_LOG_DIR/alert"
        log_info "No alerts have been generated yet."
        return 1
    fi
    
    local total_alerts=$(wc -l < "$SNORT_LOG_DIR/alert" 2>/dev/null || echo "0")
    log_info "Total alerts: $total_alerts"
    
    if [[ $total_alerts -gt 0 ]]; then
        echo
        log_info "Last 20 alerts:"
        sudo tail -20 "$SNORT_LOG_DIR/alert" | nl
    else
        log_info "No alerts found in log file."
    fi
}

test_rules() {
    log_info "🧪 Testing Snort Configuration"
    echo "==============================="
    
    if [[ ! -f "$SNORT_CONFIG" ]]; then
        log_error "Configuration file not found: $SNORT_CONFIG"
        return 1
    fi
    
    log_info "Running configuration test..."
    if sudo snort -T -c "$SNORT_CONFIG"; then
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
                # Check if Snort is running and stop it
                local status=$(check_service_status "snort" "$SNORT_PID_FILE")
                if [[ "$status" == "running" ]]; then
                    if confirm_action "Snort is running. Stop it to change interface?" "y"; then
                        stop_snort
                    else
                        log_info "Interface change cancelled"
                        return 0
                    fi
                fi
                
                INTERFACE="$new_interface"
                log_success "✅ Interface changed to: $INTERFACE"
                log_info "You can now start Snort with the new interface"
                return 0
            else
                log_error "Interface '$new_interface' does not exist. Please try again."
            fi
        else
            log_error "Please enter a valid interface name or 'cancel'."
        fi
    done
}

show_menu() {
    echo
    echo "=== SNORT IDS CONTROLLER ==="
    echo "1. Start Snort"
    echo "2. Stop Snort"
    echo "3. Restart Snort"
    echo "4. Check Status"
    echo "5. View Real-time Alerts"
    echo "6. View Alert Log"
    echo "7. Test Configuration"
    echo "8. Change Network Interface (current: $INTERFACE)"
    echo "9. Exit"
    echo "============================"
}

# Main menu loop with enhanced error handling
while true; do
    show_menu
    read -p "Choose option (1-9): " choice
    
    case $choice in
        1) 
            start_snort
            ;;
        2) 
            stop_snort
            ;;
        3) 
            log_info "Restarting Snort..."
            stop_snort
            sleep 2
            start_snort
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
            test_rules
            ;;
        8) 
            change_interface
            ;;
        9) 
            log_info "👋 Goodbye!"
            exit 0
            ;;
        *) 
            log_error "❌ Invalid option. Please choose 1-9."
            ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
    clear
done