#!/bin/bash

# SSH Management System - go2
# Usage: go2 <server-name> | go2 add | go2 list

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/servers.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo -e "${BLUE}Usage:${NC}"
    echo -e "  go2 <server-name>    ${CYAN}Connect to a server${NC}"
    echo -e "  go2 add              ${CYAN}Add a new server interactively${NC}"
    echo -e "  go2 list             ${CYAN}List all configured servers${NC}"
    echo ""
    echo -e "${BLUE}Available servers:${NC}"
    list_servers
    exit 1
}

# Function to list available servers
list_servers() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}No servers configured. Use 'go2 add' to add servers.${NC}"
        return
    fi
    
    echo ""
    local count=0
    while IFS='|' read -r name host user port key_file password options; do
        # Skip empty lines and comments
        [[ -z "$name" || "$name" =~ ^#.*$ ]] && continue
        count=$((count + 1))
        local auth_method=""
        if [ -n "$key_file" ]; then
            auth_method=" (key: ${key_file})"
        elif [ -n "$password" ]; then
            auth_method=" (password)"
        fi
        local port_info=""
        [ -n "$port" ] && [ "$port" != "22" ] && port_info=":${port}"
        echo -e "  ${GREEN}${name}${NC} -> ${user}@${host}${port_info}${auth_method}"
    done < "$CONFIG_FILE"
    
    if [ $count -eq 0 ]; then
        echo -e "${YELLOW}No servers configured. Use 'go2 add' to add servers.${NC}"
    fi
    echo ""
}

# Function to find server configuration
find_server() {
    local server_name=$1
    if [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi
    
    while IFS='|' read -r name host user port key_file password options; do
        # Skip empty lines and comments
        [[ -z "$name" || "$name" =~ ^#.*$ ]] && continue
        
        if [ "$name" == "$server_name" ]; then
            SERVER_HOST="$host"
            SERVER_USER="$user"
            SERVER_PORT="${port:-22}"
            SERVER_KEY="$key_file"
            SERVER_PASSWORD="$password"
            SERVER_OPTIONS="$options"
            return 0
        fi
    done < "$CONFIG_FILE"
    
    return 1
}

# Function to validate input doesn't contain pipe character
validate_no_pipe() {
    local input="$1"
    local field_name="$2"
    if [[ "$input" == *"|"* ]]; then
        echo -e "${RED}Error:${NC} ${field_name} cannot contain the pipe character '|'. Please try again."
        return 1
    fi
    return 0
}

# Function to add a new server interactively
add_server() {
    echo -e "${BLUE}=== Add New Server ===${NC}"
    echo ""
    
    # Get server name
    while true; do
        read -p "Server name (alias): " server_name
        if [ -z "$server_name" ]; then
            echo -e "${RED}Error:${NC} Server name cannot be empty."
            continue
        fi
        if validate_no_pipe "$server_name" "Server name"; then
            break
        fi
    done
    
    # Check if server already exists
    if find_server "$server_name" > /dev/null 2>&1; then
        echo -e "${RED}Error:${NC} Server '${server_name}' already exists."
        read -p "Overwrite? (y/N): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            exit 0
        fi
        # Remove existing entry
        grep -v "^${server_name}|" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" 2>/dev/null || true
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    fi
    
    # Get host
    while true; do
        read -p "Hostname or IP: " host
        if [ -z "$host" ]; then
            echo -e "${RED}Error:${NC} Host cannot be empty."
            continue
        fi
        if validate_no_pipe "$host" "Hostname"; then
            break
        fi
    done
    
    # Get username
    while true; do
        read -p "Username [$(whoami)]: " user
        user="${user:-$(whoami)}"
        if validate_no_pipe "$user" "Username"; then
            break
        fi
    done
    
    # Get port
    while true; do
        read -p "Port [22]: " port
        port="${port:-22}"
        if validate_no_pipe "$port" "Port"; then
            break
        fi
    done
    
    # Get authentication method
    echo ""
    echo "Authentication method:"
    echo "  1) SSH Key"
    echo "  2) Password"
    echo "  3) None (use default SSH keys)"
    read -p "Choose [3]: " auth_choice
    auth_choice="${auth_choice:-3}"
    
    key_file=""
    password=""
    
    case $auth_choice in
        1)
            while true; do
                read -p "SSH key file path [~/.ssh/id_rsa]: " key_file
                key_file="${key_file:-~/.ssh/id_rsa}"
                if validate_no_pipe "$key_file" "SSH key file path"; then
                    break
                fi
            done
            ;;
        2)
            while true; do
                read -sp "Password: " password
                echo ""
                if validate_no_pipe "$password" "Password"; then
                    break
                fi
            done
            if [ -z "$password" ]; then
                echo -e "${YELLOW}Warning:${NC} Empty password. You'll be prompted during connection."
            else
                echo -e "${YELLOW}Warning:${NC} Password will be stored in plain text. Consider using SSH keys for better security."
            fi
            ;;
        3)
            key_file=""
            password=""
            ;;
        *)
            echo -e "${YELLOW}Invalid choice. Using default SSH keys.${NC}"
            ;;
    esac
    
    # Get additional options
    echo ""
    while true; do
        read -p "Additional SSH options (optional, e.g., -o ServerAliveInterval=60): " options
        options="${options:-}"
        if validate_no_pipe "$options" "SSH options"; then
            break
        fi
    done
    
    # Write to config file
    echo "${server_name}|${host}|${user}|${port}|${key_file}|${password}|${options}" >> "$CONFIG_FILE"
    
    echo ""
    echo -e "${GREEN}✓${NC} Server '${server_name}' added successfully!"
    echo ""
    echo "Connect using: ${CYAN}go2 ${server_name}${NC}"
}

# Function to check if expect is available
check_expect() {
    if command -v expect > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to create and execute expect script for password authentication
ssh_with_password() {
    local ssh_args=("${@:1:$#-1}")  # All arguments except the last
    local password="${!#}"           # Last argument is the password
    local expect_script=$(mktemp)
    local ssh_args_file=$(mktemp)
    
    # Set up trap to ensure temp files are cleaned up even on interrupt
    trap 'rm -f "$expect_script" "$ssh_args_file"' EXIT INT TERM
    
    # Escape the password for expect
    local escaped_password=$(echo "$password" | sed 's/[[\$*+?.^|(){}]/\\&/g')
    
    # Build the SSH command arguments list for expect
    # We'll write each argument on a separate line and read them into a Tcl list
    printf '%s\n' "${ssh_args[@]}" > "$ssh_args_file"
    
    # Escape the file path for use in expect script
    local escaped_args_file=$(echo "$ssh_args_file" | sed 's/[[\$*+?.^|(){}]/\\&/g')
    
    cat > "$expect_script" << EOF
#!/usr/bin/expect -f
set timeout 30
set password "$escaped_password"

# Read SSH arguments from file and build command
set ssh_args {}
set f [open "$escaped_args_file" r]
while {[gets \$f line] >= 0} {
    lappend ssh_args \$line
}
close \$f
file delete "$escaped_args_file"

spawn {*}\$ssh_args

expect {
    -re "(?i)(password|Password):" {
        send "\$password\r"
        exp_continue
    }
    "(yes/no)" {
        send "yes\r"
        exp_continue
    }
    "Are you sure you want to continue connecting" {
        send "yes\r"
        exp_continue
    }
    timeout {
        puts "Connection timed out"
        exit 1
    }
    eof {
        exit
    }
}

# Pass control to the user after successful login
interact
EOF
    
    chmod +x "$expect_script"
    expect -f "$expect_script"
    local exit_code=$?
    
    # Clean up trap and temp files
    trap - EXIT INT TERM
    rm -f "$expect_script" "$ssh_args_file"
    return $exit_code
}

# Main execution
if [ $# -eq 0 ]; then
    usage
fi

COMMAND=$1

# Handle special commands
case "$COMMAND" in
    add)
        add_server
        exit 0
        ;;
    list)
        list_servers
        exit 0
        ;;
    help|--help|-h)
        usage
        exit 0
        ;;
esac

# Otherwise, treat as server name
SERVER_NAME=$COMMAND

# Find server configuration
if ! find_server "$SERVER_NAME"; then
    echo -e "${RED}Error:${NC} Server '${SERVER_NAME}' not found in configuration."
    echo ""
    list_servers
    exit 1
fi

# Build SSH command using Bash array (secure, no eval)
SSH_ARGS=("ssh")

# Handle password authentication
USE_PASSWORD_AUTH=false
if [ -n "$SERVER_PASSWORD" ]; then
    if check_expect; then
        USE_PASSWORD_AUTH=true
    else
        echo -e "${YELLOW}Warning:${NC} Password specified but 'expect' not found."
        echo -e "${YELLOW}Falling back to interactive password prompt...${NC}"
        echo ""
    fi
fi

# Add port if specified
if [ -n "$SERVER_PORT" ] && [ "$SERVER_PORT" != "22" ]; then
    SSH_ARGS+=("-p" "$SERVER_PORT")
fi

# Add key file if specified (and not using password)
if [ -n "$SERVER_KEY" ] && [ -z "$SERVER_PASSWORD" ]; then
    # Expand ~ to home directory
    SERVER_KEY="${SERVER_KEY/#\~/$HOME}"
    if [ -f "$SERVER_KEY" ]; then
        SSH_ARGS+=("-i" "$SERVER_KEY")
    else
        echo -e "${YELLOW}Warning:${NC} Key file '$SERVER_KEY' not found. Continuing without it."
    fi
fi

# Add additional options if specified
# Parse SERVER_OPTIONS - it may contain multiple space-separated options
# Since we've validated no pipes exist, we can safely split by spaces
if [ -n "$SERVER_OPTIONS" ]; then
    # Split SERVER_OPTIONS by spaces into array elements
    # This is safe because we've validated the input doesn't contain pipes
    IFS=' ' read -ra OPTIONS_ARRAY <<< "$SERVER_OPTIONS"
    SSH_ARGS+=("${OPTIONS_ARRAY[@]}")
fi

# Add user and host
SSH_ARGS+=("${SERVER_USER}@${SERVER_HOST}")

# Display connection info
auth_info=""
if [ -n "$SERVER_PASSWORD" ]; then
    auth_info=" (password auth)"
elif [ -n "$SERVER_KEY" ]; then
    auth_info=" (key: ${SERVER_KEY})"
fi

echo -e "${BLUE}Connecting to:${NC} ${GREEN}${SERVER_NAME}${NC} (${SERVER_USER}@${SERVER_HOST}:${SERVER_PORT})${auth_info}"
echo ""

# Execute SSH connection
if [ "$USE_PASSWORD_AUTH" = true ]; then
    ssh_with_password "${SSH_ARGS[@]}" "$SERVER_PASSWORD"
else
    "${SSH_ARGS[@]}"
fi

