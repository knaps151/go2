#!/bin/bash

# SSH Management System - go2
# Usage: go2 <server-name> | go2 add | go2 list

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/servers.conf"

# Reserved command names that cannot be used as server names
RESERVED_NAMES=("add" "list" "help" "--help" "-h")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    printf '%b\n' "${BLUE}Usage:${NC}"
    printf '%b\n' "  go2 <server-name>    ${CYAN}Connect to a server${NC}"
    printf '%b\n' "  go2 add              ${CYAN}Add a new server interactively${NC}"
    printf '%b\n' "  go2 list             ${CYAN}List all configured servers${NC}"
    printf '\n'
    printf '%b\n' "${BLUE}Available servers:${NC}"
    list_servers
}

# Function to warn if config file has insecure permissions
check_config_permissions() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return
    fi
    
    local perms
    if [[ "$OSTYPE" == "darwin"* ]]; then
        perms=$(stat -f '%A' "$CONFIG_FILE" 2>/dev/null) || return
    else
        perms=$(stat -c '%a' "$CONFIG_FILE" 2>/dev/null) || return
    fi
    
    # Check if group or world has any permissions (not 600 or stricter)
    if [[ "$perms" != "600" && "$perms" != "400" ]]; then
        printf '%b\n' "${YELLOW}Warning:${NC} Config file has insecure permissions ($perms). Run: chmod 600 \"$CONFIG_FILE\"" >&2
    fi
}

# Function to append to config file securely
append_config_secure() {
    local line="$1"
    local old_umask
    old_umask=$(umask)
    umask 077
    printf '%s\n' "$line" >> "$CONFIG_FILE"
    umask "$old_umask"
}

# Function to strip CR from line (handles CRLF line endings from Windows/WSL)
strip_cr() {
    printf '%s' "${1//$'\r'/}"
}

# Function to list available servers
list_servers() {
    if [ ! -f "$CONFIG_FILE" ]; then
        printf '%b\n' "${YELLOW}No servers configured. Use 'go2 add' to add servers.${NC}"
        return
    fi
    
    check_config_permissions
    
    printf '\n'
    local count=0
    local line
    while IFS='|' read -r name host user port key_file password options || [[ -n "$name" ]]; do
        # Strip CR from the last field (options) and other fields
        name=$(strip_cr "$name")
        host=$(strip_cr "$host")
        user=$(strip_cr "$user")
        port=$(strip_cr "$port")
        key_file=$(strip_cr "$key_file")
        password=$(strip_cr "$password")
        options=$(strip_cr "$options")
        
        # Skip empty lines and comments (including indented comments)
        [[ -z "$name" || "$name" =~ ^[[:space:]]*# ]] && continue
        
        count=$((count + 1))
        local auth_method=""
        if [ -n "$password" ]; then
            auth_method=" (password)"
        elif [ -n "$key_file" ]; then
            auth_method=" (key: ${key_file})"
        fi
        local port_info=""
        [ -n "$port" ] && [ "$port" != "22" ] && port_info=":${port}"
        printf '%b\n' "  ${GREEN}${name}${NC} -> ${user}@${host}${port_info}${auth_method}"
    done < "$CONFIG_FILE"
    
    if [ $count -eq 0 ]; then
        printf '%b\n' "${YELLOW}No servers configured. Use 'go2 add' to add servers.${NC}"
    fi
    printf '\n'
}

# Function to find server configuration
find_server() {
    local server_name=$1
    if [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi
    
    local name host user port key_file password options
    while IFS='|' read -r name host user port key_file password options || [[ -n "$name" ]]; do
        # Strip CR from all fields
        name=$(strip_cr "$name")
        host=$(strip_cr "$host")
        user=$(strip_cr "$user")
        port=$(strip_cr "$port")
        key_file=$(strip_cr "$key_file")
        password=$(strip_cr "$password")
        options=$(strip_cr "$options")
        
        # Skip empty lines and comments
        [[ -z "$name" || "$name" =~ ^[[:space:]]*# ]] && continue
        
        if [ "$name" = "$server_name" ]; then
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

# Function to check if a server name exists in the config (exact match)
server_exists() {
    local server_name=$1
    if [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi
    
    local name
    while IFS='|' read -r name _ || [[ -n "$name" ]]; do
        name=$(strip_cr "$name")
        [[ -z "$name" || "$name" =~ ^[[:space:]]*# ]] && continue
        if [ "$name" = "$server_name" ]; then
            return 0
        fi
    done < "$CONFIG_FILE"
    
    return 1
}

# Function to remove a server from config (exact match, not regex)
remove_server_from_config() {
    local server_name=$1
    local temp_file
    temp_file=$(mktemp)
    
    local name rest
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Extract the server name (first field before |)
        name="${line%%|*}"
        name=$(strip_cr "$name")
        
        # Keep the line if it's not an exact match or if it's a comment/empty
        if [[ -z "$name" || "$name" =~ ^[[:space:]]*# || "$name" != "$server_name" ]]; then
            printf '%s\n' "$line"
        fi
    done < "$CONFIG_FILE" > "$temp_file"
    
    # Use secure write
    local old_umask
    old_umask=$(umask)
    umask 077
    mv "$temp_file" "$CONFIG_FILE"
    umask "$old_umask"
}

# Function to validate input doesn't contain pipe character
validate_no_pipe() {
    local input="$1"
    local field_name="$2"
    if [[ "$input" == *"|"* ]]; then
        printf '%b\n' "${RED}Error:${NC} ${field_name} cannot contain the pipe character '|'. Please try again."
        return 1
    fi
    return 0
}

# Function to validate server name
validate_server_name() {
    local name="$1"
    
    # Check for empty
    if [ -z "$name" ]; then
        printf '%b\n' "${RED}Error:${NC} Server name cannot be empty."
        return 1
    fi
    
    # Check for reserved names
    for reserved in "${RESERVED_NAMES[@]}"; do
        if [ "$name" = "$reserved" ]; then
            printf '%b\n' "${RED}Error:${NC} '$name' is a reserved command name and cannot be used as a server name."
            return 1
        fi
    done
    
    # Check for whitespace
    if [[ "$name" =~ [[:space:]] ]]; then
        printf '%b\n' "${RED}Error:${NC} Server name cannot contain whitespace."
        return 1
    fi
    
    # Check for regex special characters that could cause issues
    # Allow alphanumeric, dash, underscore, and dot
    if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        printf '%b\n' "${RED}Error:${NC} Server name can only contain letters, numbers, dots, dashes, and underscores."
        return 1
    fi
    
    # Check for pipe
    if ! validate_no_pipe "$name" "Server name"; then
        return 1
    fi
    
    return 0
}

# Function to validate port number
validate_port() {
    local port="$1"
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        printf '%b\n' "${RED}Error:${NC} Port must be a number."
        return 1
    fi
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        printf '%b\n' "${RED}Error:${NC} Port must be between 1 and 65535."
        return 1
    fi
    return 0
}

# Function to validate host/user don't start with -
validate_ssh_arg() {
    local value="$1"
    local field_name="$2"
    if [[ "$value" == -* ]]; then
        printf '%b\n' "${RED}Error:${NC} ${field_name} cannot start with '-'."
        return 1
    fi
    return 0
}

# Function to add a new server interactively
add_server() {
    printf '%b\n' "${BLUE}=== Add New Server ===${NC}"
    printf '\n'
    
    check_config_permissions
    
    local server_name host user port key_file password options
    local existing_entry=""
    
    # Get server name
    while true; do
        IFS= read -r -p "Server name (alias): " server_name
        if ! validate_server_name "$server_name"; then
            continue
        fi
        break
    done
    
    # Check if server already exists and save existing entry
    if server_exists "$server_name"; then
        printf '%b\n' "${YELLOW}Warning:${NC} Server '${server_name}' already exists."
        IFS= read -r -p "Overwrite? (y/N): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            printf '%s\n' "Cancelled."
            exit 0
        fi
        # Save the config content without this entry BEFORE prompting for new values
        # This way if user Ctrl-C's during input, the old entry is preserved
        existing_entry="will_overwrite"
    fi
    
    # Get host
    while true; do
        IFS= read -r -p "Hostname or IP: " host
        if [ -z "$host" ]; then
            printf '%b\n' "${RED}Error:${NC} Host cannot be empty."
            continue
        fi
        if ! validate_no_pipe "$host" "Hostname"; then
            continue
        fi
        if ! validate_ssh_arg "$host" "Hostname"; then
            continue
        fi
        break
    done
    
    # Get username
    while true; do
        IFS= read -r -p "Username [$(whoami)]: " user
        user="${user:-$(whoami)}"
        if ! validate_no_pipe "$user" "Username"; then
            continue
        fi
        if ! validate_ssh_arg "$user" "Username"; then
            continue
        fi
        break
    done
    
    # Get port
    while true; do
        IFS= read -r -p "Port [22]: " port
        port="${port:-22}"
        if ! validate_no_pipe "$port" "Port"; then
            continue
        fi
        if ! validate_port "$port"; then
            continue
        fi
        break
    done
    
    # Get authentication method
    printf '\n'
    printf '%s\n' "Authentication method:"
    printf '%s\n' "  1) SSH Key"
    printf '%s\n' "  2) Password"
    printf '%s\n' "  3) None (use default SSH keys)"
    IFS= read -r -p "Choose [3]: " auth_choice
    auth_choice="${auth_choice:-3}"
    
    key_file=""
    password=""
    
    case $auth_choice in
        1)
            while true; do
                IFS= read -r -p "SSH key file path [~/.ssh/id_rsa]: " key_file
                key_file="${key_file:-~/.ssh/id_rsa}"
                if ! validate_no_pipe "$key_file" "SSH key file path"; then
                    continue
                fi
                break
            done
            ;;
        2)
            while true; do
                IFS= read -r -s -p "Password: " password
                printf '\n'
                if ! validate_no_pipe "$password" "Password"; then
                    continue
                fi
                break
            done
            if [ -z "$password" ]; then
                printf '%b\n' "${YELLOW}Warning:${NC} Empty password. You'll be prompted during connection."
            else
                printf '%b\n' "${YELLOW}Warning:${NC} Password will be stored in plain text. Consider using SSH keys for better security."
            fi
            ;;
        3)
            key_file=""
            password=""
            ;;
        *)
            printf '%b\n' "${YELLOW}Invalid choice. Using default SSH keys.${NC}"
            ;;
    esac
    
    # Get additional options
    printf '\n'
    while true; do
        IFS= read -r -p "Additional SSH options (optional, e.g., -o ServerAliveInterval=60): " options
        options="${options:-}"
        if ! validate_no_pipe "$options" "SSH options"; then
            continue
        fi
        break
    done
    
    # Now that all prompts succeeded, remove the old entry if overwriting
    if [ -n "$existing_entry" ]; then
        remove_server_from_config "$server_name"
    fi
    
    # Write to config file securely
    local entry="${server_name}|${host}|${user}|${port}|${key_file}|${password}|${options}"
    append_config_secure "$entry"
    
    printf '\n'
    printf '%b\n' "${GREEN}✓${NC} Server '${server_name}' added successfully!"
    printf '\n'
    printf '%b\n' "Connect using: ${CYAN}go2 ${server_name}${NC}"
}

# Password auth via OpenSSH SSH_ASKPASS so ssh owns the TTY directly.
# (expect's interact breaks arrow keys / readline: keys show up as ^[[A etc.)
ssh_with_password() {
    local password="$1"
    shift
    local ssh_args=("$@")

    local askpass_script
    askpass_script=$(mktemp)
    trap 'rm -f "$askpass_script"; unset GO2_SSH_PASSWORD SSH_ASKPASS SSH_ASKPASS_REQUIRE' EXIT INT TERM

    cat > "$askpass_script" << 'ASKPASS_EOF'
#!/bin/sh
printf '%s\n' "$GO2_SSH_PASSWORD"
ASKPASS_EOF
    chmod 700 "$askpass_script"

    export GO2_SSH_PASSWORD="$password"
    export SSH_ASKPASS="$askpass_script"
    export SSH_ASKPASS_REQUIRE=force

    "${ssh_args[@]}"
    local exit_code=$?

    unset GO2_SSH_PASSWORD SSH_ASKPASS SSH_ASKPASS_REQUIRE
    rm -f "$askpass_script"
    trap - EXIT INT TERM

    return $exit_code
}

# Main execution
if [ $# -eq 0 ]; then
    usage
    exit 1
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

check_config_permissions

# Find server configuration
if ! find_server "$SERVER_NAME"; then
    printf '%b\n' "${RED}Error:${NC} Server '${SERVER_NAME}' not found in configuration."
    printf '\n'
    list_servers
    exit 1
fi

# Build SSH command using Bash array (secure, no eval)
SSH_ARGS=("ssh")

# Handle password authentication
USE_PASSWORD_AUTH=false
if [ -n "$SERVER_PASSWORD" ]; then
    USE_PASSWORD_AUTH=true
fi

# OpenSSH 10.1+ warns when the server lacks post-quantum KEX (common on
# older Raspberry Pi OS / appliances). Silence only that warning when supported.
if ssh -G -o WarnWeakCrypto=no-pq-kex localhost >/dev/null 2>&1; then
    SSH_ARGS+=("-o" "WarnWeakCrypto=no-pq-kex")
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
        printf '%b\n' "${YELLOW}Warning:${NC} Key file '$SERVER_KEY' not found. Continuing without it."
    fi
fi

# Add additional options if specified
if [ -n "$SERVER_OPTIONS" ]; then
    # Split SERVER_OPTIONS by spaces into array elements
    IFS=' ' read -r -a OPTIONS_ARRAY <<< "$SERVER_OPTIONS"
    SSH_ARGS+=("${OPTIONS_ARRAY[@]}")
fi

# Add -- to prevent user@host from being interpreted as an option
SSH_ARGS+=("--" "${SERVER_USER}@${SERVER_HOST}")

# Display connection info
auth_info=""
if [ -n "$SERVER_PASSWORD" ]; then
    auth_info=" (password auth)"
elif [ -n "$SERVER_KEY" ] && [ -f "${SERVER_KEY/#\~/$HOME}" ]; then
    auth_info=" (key: ${SERVER_KEY})"
fi

printf '%b\n' "${BLUE}Connecting to:${NC} ${GREEN}${SERVER_NAME}${NC} (${SERVER_USER}@${SERVER_HOST}:${SERVER_PORT})${auth_info}"
printf '\n'

# Execute SSH connection
if [ "$USE_PASSWORD_AUTH" = true ]; then
    ssh_with_password "$SERVER_PASSWORD" "${SSH_ARGS[@]}"
    exit $?
else
    "${SSH_ARGS[@]}"
    exit $?
fi
