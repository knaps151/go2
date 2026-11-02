#!/bin/bash

# go2 SSH Management System - Installation Script
# This script sets up go2 on your system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GO2_SCRIPT="${SCRIPT_DIR}/go2.sh"
CONFIG_FILE="${SCRIPT_DIR}/servers.conf"

# Marker comments for shell RC file
GO2_MARKER_START="# >>> go2 SSH Management System >>>"
GO2_MARKER_END="# <<< go2 SSH Management System <<<"

printf '%b\n' "${BLUE}=== go2 SSH Management System - Installation ===${NC}"
printf '\n'

# Check if go2.sh exists
if [ ! -f "$GO2_SCRIPT" ]; then
    printf '%b\n' "${RED}Error:${NC} go2.sh not found in ${SCRIPT_DIR}"
    exit 1
fi

# Make go2.sh executable
printf '%b\n' "${CYAN}Making go2.sh executable...${NC}"
chmod +x "$GO2_SCRIPT"
printf '%b\n' "${GREEN}✓${NC} Script is now executable"

# Create config file from example if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    if [ -f "${SCRIPT_DIR}/servers.conf.example" ]; then
        printf '%b\n' "${CYAN}Creating config file from example...${NC}"
        (umask 077 && cp "${SCRIPT_DIR}/servers.conf.example" "$CONFIG_FILE")
        printf '%b\n' "${GREEN}✓${NC} Config file created from example"
    else
        printf '%b\n' "${YELLOW}Note:${NC} No servers.conf found. You can create one manually or use 'go2 add'"
    fi
else
    # Set proper permissions on existing config file
    printf '%b\n' "${CYAN}Setting secure permissions on config file...${NC}"
    chmod 600 "$CONFIG_FILE"
    printf '%b\n' "${GREEN}✓${NC} Config file permissions set"
fi

# Detect shell
SHELL_NAME=$(basename "$SHELL")
SHELL_RC=""

# Determine the correct RC file based on shell and OS
if [ "$SHELL_NAME" = "zsh" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ "$SHELL_NAME" = "bash" ]; then
    # On macOS, login shells read .bash_profile, not .bashrc
    # On Linux, login shells typically read .profile and interactive shells read .bashrc
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: prefer .bash_profile for login shells
        if [ -f "$HOME/.bash_profile" ]; then
            SHELL_RC="$HOME/.bash_profile"
        else
            # Create .bash_profile if it doesn't exist
            SHELL_RC="$HOME/.bash_profile"
        fi
    else
        # Linux: use .bashrc for interactive shells
        SHELL_RC="$HOME/.bashrc"
    fi
elif [ "$SHELL_NAME" = "fish" ]; then
    SHELL_RC="$HOME/.config/fish/config.fish"
elif [ "$SHELL_NAME" = "ksh" ]; then
    SHELL_RC="$HOME/.kshrc"
else
    printf '%b\n' "${YELLOW}Warning:${NC} Shell '$SHELL_NAME' is not directly supported."
    printf '%b\n' "${YELLOW}You can still use go2 by adding it to your PATH or creating an alias manually.${NC}"
    printf '\n'
    printf '%b\n' "Option 1: Create a symlink in ~/.local/bin (recommended):"
    printf '%b\n' "  ${CYAN}mkdir -p ~/.local/bin && ln -sf \"${GO2_SCRIPT}\" ~/.local/bin/go2${NC}"
    printf '\n'
    printf '%b\n' "Option 2: Add this alias to your shell configuration file:"
    printf '%b\n' "  ${CYAN}alias go2=\"bash '${GO2_SCRIPT}'\"${NC}"
    printf '\n'
    printf '%b\n' "${GREEN}Installation partially complete.${NC}"
    printf '%b\n' "The script is ready to use once you configure your shell."
    exit 0
fi

# Build properly quoted alias line (handles paths with spaces)
# Using printf %q for proper quoting
ALIAS_LINE="alias go2='bash \"${GO2_SCRIPT}\"'"

# Function to remove existing go2 configuration using markers
remove_existing_go2() {
    local rc_file="$1"
    local temp_file
    temp_file=$(mktemp)
    
    local in_block=false
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "$GO2_MARKER_START" ]]; then
            in_block=true
            continue
        fi
        if [[ "$line" == "$GO2_MARKER_END" ]]; then
            in_block=false
            continue
        fi
        if [ "$in_block" = false ]; then
            printf '%s\n' "$line"
        fi
    done < "$rc_file" > "$temp_file"
    
    mv "$temp_file" "$rc_file"
}

# Function to check if go2 alias exists (either in markers or standalone)
go2_exists_in_rc() {
    local rc_file="$1"
    grep -q "alias go2=" "$rc_file" 2>/dev/null || grep -q "$GO2_MARKER_START" "$rc_file" 2>/dev/null
}

# Check if alias already exists
if [ -f "$SHELL_RC" ] && go2_exists_in_rc "$SHELL_RC"; then
    printf '%b\n' "${YELLOW}go2 configuration already exists in ${SHELL_RC}${NC}"
    IFS= read -r -p "Do you want to update it? (y/N): " update_alias
    if [[ "$update_alias" =~ ^[Yy]$ ]]; then
        # Create backup
        cp "$SHELL_RC" "${SHELL_RC}.go2.bak.$(date +%Y%m%d_%H%M%S)"
        
        # Remove existing configuration (try marker-based first, then legacy)
        if grep -q "$GO2_MARKER_START" "$SHELL_RC" 2>/dev/null; then
            remove_existing_go2 "$SHELL_RC"
        else
            # Remove legacy format (portable sed for macOS and Linux)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' '/alias go2=/d' "$SHELL_RC"
                sed -i '' '/# go2 SSH Management System$/d' "$SHELL_RC"
            else
                sed -i '/alias go2=/d' "$SHELL_RC"
                sed -i '/# go2 SSH Management System$/d' "$SHELL_RC"
            fi
        fi
        
        # Add new configuration with markers
        {
            printf '\n'
            printf '%s\n' "$GO2_MARKER_START"
            printf '%s\n' "$ALIAS_LINE"
            printf '%s\n' "$GO2_MARKER_END"
        } >> "$SHELL_RC"
        printf '%b\n' "${GREEN}✓${NC} Alias updated in ${SHELL_RC}"
    else
        printf '%b\n' "${YELLOW}Skipping alias update${NC}"
    fi
else
    # Add alias to shell config with markers
    printf '%b\n' "${CYAN}Adding alias to ${SHELL_RC}...${NC}"
    {
        printf '\n'
        printf '%s\n' "$GO2_MARKER_START"
        printf '%s\n' "$ALIAS_LINE"
        printf '%s\n' "$GO2_MARKER_END"
    } >> "$SHELL_RC"
    printf '%b\n' "${GREEN}✓${NC} Alias added to ${SHELL_RC}"
fi

# Password auth uses OpenSSH SSH_ASKPASS (no expect dependency)
printf '%b\n' "${GREEN}✓${NC} Password authentication uses OpenSSH SSH_ASKPASS (arrow keys / full TTY work)"

printf '\n'
printf '%b\n' "${GREEN}=== Installation Complete! ===${NC}"
printf '\n'
printf '%s\n' "To start using go2, run:"
printf '%b\n' "  ${CYAN}source ${SHELL_RC}${NC}"
printf '%b\n' "  ${CYAN}go2 add${NC}  (to add your first server)"
printf '\n'
printf '%s\n' "Or open a new terminal window and run:"
printf '%b\n' "  ${CYAN}go2 add${NC}"
printf '\n'
