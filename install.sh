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

echo -e "${BLUE}=== go2 SSH Management System - Installation ===${NC}"
echo ""

# Check if go2.sh exists
if [ ! -f "$GO2_SCRIPT" ]; then
    echo -e "${RED}Error:${NC} go2.sh not found in ${SCRIPT_DIR}"
    exit 1
fi

# Make go2.sh executable
echo -e "${CYAN}Making go2.sh executable...${NC}"
chmod +x "$GO2_SCRIPT"
echo -e "${GREEN}✓${NC} Script is now executable"

# Create config file from example if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    if [ -f "${SCRIPT_DIR}/servers.conf.example" ]; then
        echo -e "${CYAN}Creating config file from example...${NC}"
        cp "${SCRIPT_DIR}/servers.conf.example" "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
        echo -e "${GREEN}✓${NC} Config file created from example"
    else
        echo -e "${YELLOW}Note:${NC} No servers.conf found. You can create one manually or use 'go2 add'"
    fi
else
    # Set proper permissions on existing config file
    echo -e "${CYAN}Setting secure permissions on config file...${NC}"
    chmod 600 "$CONFIG_FILE"
    echo -e "${GREEN}✓${NC} Config file permissions set"
fi

# Detect shell
SHELL_NAME=$(basename "$SHELL")
SHELL_RC=""

if [ "$SHELL_NAME" = "zsh" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ "$SHELL_NAME" = "bash" ]; then
    if [ -f "$HOME/.bash_profile" ]; then
        SHELL_RC="$HOME/.bash_profile"
    else
        SHELL_RC="$HOME/.bashrc"
    fi
else
    echo -e "${YELLOW}Warning:${NC} Unsupported shell: $SHELL_NAME"
    echo -e "${YELLOW}Please manually add the alias to your shell configuration file.${NC}"
    exit 1
fi

# Check if alias already exists
ALIAS_LINE="alias go2=\"bash ${GO2_SCRIPT}\""

if grep -q "alias go2=" "$SHELL_RC" 2>/dev/null; then
    echo -e "${YELLOW}Alias 'go2' already exists in ${SHELL_RC}${NC}"
    read -p "Do you want to update it? (y/N): " update_alias
    if [[ "$update_alias" =~ ^[Yy]$ ]]; then
        # Remove old alias lines (portable sed for macOS and Linux)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS (BSD sed)
            sed -i.bak '/alias go2=/d' "$SHELL_RC"
        else
            # Linux (GNU sed)
            sed -i '/alias go2=/d' "$SHELL_RC"
        fi
        echo "$ALIAS_LINE" >> "$SHELL_RC"
        echo -e "${GREEN}✓${NC} Alias updated in ${SHELL_RC}"
    else
        echo -e "${YELLOW}Skipping alias update${NC}"
    fi
else
    # Add alias to shell config
    echo -e "${CYAN}Adding alias to ${SHELL_RC}...${NC}"
    echo "" >> "$SHELL_RC"
    echo "# go2 SSH Management System" >> "$SHELL_RC"
    echo "$ALIAS_LINE" >> "$SHELL_RC"
    echo -e "${GREEN}✓${NC} Alias added to ${SHELL_RC}"
fi

# Check if expect is available (for password authentication)
if command -v expect > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} 'expect' is installed (password authentication supported)"
else
    echo -e "${YELLOW}⚠${NC} 'expect' not found. Password authentication will use interactive prompts."
    echo -e "${YELLOW}   Install expect for automatic password entry (usually pre-installed on macOS)${NC}"
fi

echo ""
echo -e "${GREEN}=== Installation Complete! ===${NC}"
echo ""
echo -e "To start using go2, run:"
echo -e "  ${CYAN}source ${SHELL_RC}${NC}"
echo -e "  ${CYAN}go2 add${NC}  (to add your first server)"
echo ""
echo -e "Or open a new terminal window and run:"
echo -e "  ${CYAN}go2 add${NC}"
echo ""

