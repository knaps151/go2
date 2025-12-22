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

# Function to add a new server interactively
add_server() {
    echo -e "${BLUE}=== Add New Server ===${NC}"
    echo ""
    
    # Get server name
    read -p "Server name (alias): " server_name
    if [ -z "$server_name" ]; then
        echo -e "${RED}Error:${NC} Server name cannot be empty."
        exit 1
    fi
    
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
    read -p "Hostname or IP: " host
    if [ -z "$host" ]; then
        echo -e "${RED}Error:${NC} Host cannot be empty."
        exit 1
    fi
    
    # Get username
    read -p "Username [$(whoami)]: " user
    user="${user:-$(whoami)}"
    
    # Get port
    read -p "Port [22]: " port
    port="${port:-22}"
    
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
            read -p "SSH key file path [~/.ssh/id_rsa]: " key_file
            key_file="${key_file:-~/.ssh/id_rsa}"
            ;;
        2)
            read -sp "Password: " password
            echo ""
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
    read -p "Additional SSH options (optional, e.g., -o ServerAliveInterval=60): " options
    options="${options:-}"
    
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
    local ssh_cmd="$1"
    local password="$2"
    local expect_script=$(mktemp)
    
    # Escape the password for expect
    local escaped_password=$(echo "$password" | sed 's/[[\$*+?.^|(){}]/\\&/g')
    
    cat > "$expect_script" << EOF
#!/usr/bin/expect -f
set timeout 30
set password "$escaped_password"

spawn $ssh_cmd

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
    rm -f "$expect_script"
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

# Build SSH command
SSH_CMD=""

# Handle password authentication
USE_PASSWORD_AUTH=false
if [ -n "$SERVER_PASSWORD" ]; then
    if check_expect; then
        USE_PASSWORD_AUTH=true
        SSH_CMD="ssh"
    else
        echo -e "${YELLOW}Warning:${NC} Password specified but 'expect' not found."
        echo -e "${YELLOW}Falling back to interactive password prompt...${NC}"
        echo ""
        SSH_CMD="ssh"
    fi
else
    SSH_CMD="ssh"
fi

# Add port if specified
if [ -n "$SERVER_PORT" ] && [ "$SERVER_PORT" != "22" ]; then
    SSH_CMD="$SSH_CMD -p $SERVER_PORT"
fi

# Add key file if specified (and not using password)
if [ -n "$SERVER_KEY" ] && [ -z "$SERVER_PASSWORD" ]; then
    # Expand ~ to home directory
    SERVER_KEY="${SERVER_KEY/#\~/$HOME}"
    if [ -f "$SERVER_KEY" ]; then
        SSH_CMD="$SSH_CMD -i $SERVER_KEY"
    else
        echo -e "${YELLOW}Warning:${NC} Key file '$SERVER_KEY' not found. Continuing without it."
    fi
fi

# Add additional options if specified
if [ -n "$SERVER_OPTIONS" ]; then
    SSH_CMD="$SSH_CMD $SERVER_OPTIONS"
fi

# Add user and host
SSH_CMD="$SSH_CMD ${SERVER_USER}@${SERVER_HOST}"

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
    ssh_with_password "$SSH_CMD" "$SERVER_PASSWORD"
else
    eval "$SSH_CMD"
fi

