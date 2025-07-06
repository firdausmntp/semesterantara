#!/bin/bash
# File: common_functions.sh
# Common functions library for IDS scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Progress indicator
show_progress() {
    local duration=$1
    local message=$2
    echo -n "$message"
    for i in $(seq 1 $duration); do
        echo -n "."
        sleep 1
    done
    echo " Done!"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running as root/sudo
check_sudo() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root directly. Use sudo for individual commands."
        exit 1
    fi
    
    if ! sudo -n true 2>/dev/null; then
        log_info "This script requires sudo privileges. You may be prompted for your password."
    fi
}

# Validate user input (y/n)
confirm_action() {
    local message="$1"
    local default="${2:-n}"
    
    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$message [Y/n]: " yn
            yn=${yn:-y}
        else
            read -p "$message [y/N]: " yn
            yn=${yn:-n}
        fi
        
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Check package installation
check_package() {
    local package="$1"
    if dpkg -l | grep -q "^ii  $package "; then
        return 0
    else
        return 1
    fi
}

# Install package with confirmation
install_package() {
    local package="$1"
    local description="$2"
    
    if check_package "$package"; then
        log_info "$package is already installed"
        return 0
    fi
    
    log_info "Installing $package ($description)..."
    if sudo apt install -y "$package"; then
        log_success "$package installed successfully"
        return 0
    else
        log_error "Failed to install $package"
        return 1
    fi
}

# Enhanced network interface detection
get_available_interfaces() {
    # Get all interfaces except loopback, with their status
    ip -o link show | awk -F': ' '
    $2 !~ /^lo$/ {
        interface = $2
        status = "DOWN"
        if (match($0, /state UP/)) status = "UP"
        if (match($0, /state UNKNOWN/)) status = "UNKNOWN"
        print interface ":" status
    }'
}

# Filter interfaces by status
get_active_interfaces() {
    get_available_interfaces | grep -E ":(UP|UNKNOWN)$" | cut -d: -f1
}

# Get default route interface
get_default_interface() {
    ip route | grep "^default" | awk '{print $5}' | head -1
}

# Robust interface detection with fallbacks
detect_network_interface() {
    local interface=""
    local auto_detect="${1:-true}"
    
    log_info "Detecting network interface..."
    
    # Method 1: Try default route
    interface=$(get_default_interface)
    if [[ -n "$interface" && "$interface" != "lo" ]]; then
        log_info "Default interface detected: $interface"
        if [[ "$auto_detect" == "true" ]]; then
            echo "$interface"
            return 0
        fi
    fi
    
    # Method 2: Get first active non-loopback interface
    local active_interfaces=($(get_active_interfaces))
    if [[ ${#active_interfaces[@]} -gt 0 ]]; then
        if [[ -z "$interface" ]]; then
            interface="${active_interfaces[0]}"
            log_info "First active interface detected: $interface"
        fi
    fi
    
    # Show available interfaces and let user choose
    echo
    log_info "Available network interfaces:"
    echo "Interface  Status"
    echo "--------------------"
    get_available_interfaces | while IFS=: read -r iface status; do
        if [[ "$iface" == "$interface" ]]; then
            echo "* $iface      $status (detected)"
        else
            echo "  $iface      $status"
        fi
    done
    echo
    
    # Get user input with validation
    while true; do
        if [[ -n "$interface" ]]; then
            read -p "Use detected interface '$interface'? [Y/n] or enter different interface name: " user_input
            if [[ -z "$user_input" || "$user_input" =~ ^[Yy]$ ]]; then
                user_input="$interface"
                break
            elif [[ "$user_input" =~ ^[Nn]$ ]]; then
                read -p "Enter interface name: " user_input
            fi
        else
            read -p "Enter interface name: " user_input
        fi
        
        # Validate interface exists
        if [[ -n "$user_input" ]]; then
            if ip link show "$user_input" >/dev/null 2>&1; then
                interface="$user_input"
                break
            else
                log_error "Interface '$user_input' does not exist. Please try again."
            fi
        else
            log_error "Please enter a valid interface name."
        fi
    done
    
    echo "$interface"
}

# Detect local network with fallbacks
detect_local_network() {
    local interface="$1"
    local network=""
    
    log_info "Detecting local network for interface $interface..."
    
    # Method 1: Get network from interface IP and netmask
    local ip_info=$(ip addr show "$interface" 2>/dev/null | grep -E 'inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    if [[ -n "$ip_info" ]]; then
        network=$(echo "$ip_info" | awk '{print $2}' | head -1)
        if [[ -n "$network" && "$network" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
            # Convert to network address
            local ip=$(echo "$network" | cut -d/ -f1)
            local prefix=$(echo "$network" | cut -d/ -f2)
            network=$(ipcalc-ng "$ip/$prefix" --network --prefix 2>/dev/null | grep -E '^NETWORK=' | cut -d= -f2)
            if [[ -n "$network" ]]; then
                log_info "Network detected from interface: $network"
                echo "$network"
                return 0
            fi
        fi
    fi
    
    # Method 2: Try common private network patterns from route table
    local route_networks=$(ip route | grep -E '192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.' | grep "$interface" | awk '{print $1}' | head -1)
    if [[ -n "$route_networks" ]]; then
        network="$route_networks"
        log_info "Network detected from routes: $network"
        echo "$network"
        return 0
    fi
    
    # Method 3: Manual input with validation
    while true; do
        echo
        log_warning "Could not automatically detect network. Please enter manually."
        echo "Examples: 192.168.1.0/24, 10.0.0.0/8, 172.16.0.0/16"
        read -p "Enter your local network (CIDR notation): " user_network
        
        if [[ -n "$user_network" ]]; then
            # Basic CIDR validation
            if [[ "$user_network" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
                echo "$user_network"
                return 0
            else
                log_error "Invalid network format. Please use CIDR notation (e.g., 192.168.1.0/24)"
            fi
        fi
    done
}

# Validate service status
check_service_status() {
    local service_name="$1"
    local pid_file="$2"
    
    # Check by PID file if provided
    if [[ -n "$pid_file" && -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file" 2>/dev/null)
        if [[ -n "$pid" ]] && ps -p "$pid" >/dev/null 2>&1; then
            echo "running"
            return 0
        else
            # PID file exists but process is dead
            if [[ -f "$pid_file" ]]; then
                log_warning "Stale PID file found for $service_name, cleaning up..."
                sudo rm -f "$pid_file"
            fi
        fi
    fi
    
    # Check by process name
    if pgrep "$service_name" >/dev/null 2>&1; then
        echo "running"
        return 0
    fi
    
    echo "stopped"
    return 1
}

# Create directory with proper permissions
create_directory() {
    local dir_path="$1"
    local owner="${2:-root}"
    local group="${3:-root}"
    local permissions="${4:-755}"
    
    if [[ ! -d "$dir_path" ]]; then
        log_info "Creating directory: $dir_path"
        sudo mkdir -p "$dir_path"
        sudo chmod "$permissions" "$dir_path"
        sudo chown "$owner:$group" "$dir_path"
        log_success "Directory created: $dir_path"
    else
        log_info "Directory already exists: $dir_path"
    fi
}

# Backup file with timestamp
backup_file() {
    local file_path="$1"
    local backup_suffix="${2:-$(date +%Y%m%d_%H%M%S)}"
    
    if [[ -f "$file_path" ]]; then
        local backup_path="${file_path}.backup_${backup_suffix}"
        log_info "Backing up $file_path to $backup_path"
        sudo cp "$file_path" "$backup_path"
        log_success "Backup created: $backup_path"
    else
        log_info "File $file_path does not exist, no backup needed"
    fi
}

# Test network connectivity
test_connectivity() {
    local host="${1:-8.8.8.8}"
    local timeout="${2:-5}"
    
    if ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}