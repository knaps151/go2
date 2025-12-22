#!/bin/bash

# go2 SSH Management System - Uninstallation Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== go2 SSH Management System - Uninstallation ===${NC}"
echo ""

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
    echo -e "${YELLOW}Please manually remove the alias from your shell configuration file.${NC}"
    exit 1
fi

# Remove alias from shell config
if grep -q "alias go2=" "$SHELL_RC" 2>/dev/null; then
    echo -e "${CYAN}Removing alias from ${SHELL_RC}...${NC}"
    # Create backup
    cp "$SHELL_RC" "${SHELL_RC}.bak.$(date +%Y%m%d_%H%M%S)"
    # Remove alias lines (portable sed for macOS and Linux)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS (BSD sed)
        sed -i.bak '/alias go2=/d' "$SHELL_RC"
        sed -i.bak '/# go2 SSH Management System/d' "$SHELL_RC"
        rm -f "${SHELL_RC}.bak"
    else
        # Linux (GNU sed)
        sed -i '/alias go2=/d' "$SHELL_RC"
        sed -i '/# go2 SSH Management System/d' "$SHELL_RC"
    fi
    echo -e "${GREEN}✓${NC} Alias removed from ${SHELL_RC}"
else
    echo -e "${YELLOW}No alias found in ${SHELL_RC}${NC}"
fi

echo ""
echo -e "${GREEN}=== Uninstallation Complete! ===${NC}"
echo ""
echo -e "The alias has been removed from your shell configuration."
echo -e "To complete the uninstallation, you can:"
echo -e "  1. Delete the go2 directory: ${YELLOW}rm -rf $(pwd)${NC}"
echo -e "  2. Reload your shell: ${YELLOW}source ${SHELL_RC}${NC}"
echo ""

