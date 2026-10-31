#!/bin/bash

# go2 SSH Management System - Uninstallation Script

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get the directory where this script is located (the go2 directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Marker comments for shell RC file (must match install.sh)
GO2_MARKER_START="# >>> go2 SSH Management System >>>"
GO2_MARKER_END="# <<< go2 SSH Management System <<<"

printf '%b\n' "${BLUE}=== go2 SSH Management System - Uninstallation ===${NC}"
printf '\n'

# Detect shell
SHELL_NAME=$(basename "$SHELL")
SHELL_RC=""

if [ "$SHELL_NAME" = "zsh" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ "$SHELL_NAME" = "bash" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [ -f "$HOME/.bash_profile" ]; then
            SHELL_RC="$HOME/.bash_profile"
        else
            SHELL_RC="$HOME/.bashrc"
        fi
    else
        SHELL_RC="$HOME/.bashrc"
    fi
elif [ "$SHELL_NAME" = "fish" ]; then
    SHELL_RC="$HOME/.config/fish/config.fish"
elif [ "$SHELL_NAME" = "ksh" ]; then
    SHELL_RC="$HOME/.kshrc"
else
    printf '%b\n' "${YELLOW}Warning:${NC} Shell '$SHELL_NAME' is not directly supported."
    printf '%b\n' "${YELLOW}Please manually remove any go2 alias from your shell configuration file.${NC}"
    printf '\n'
    printf '%b\n' "Also check and remove any symlinks:"
    printf '%b\n' "  ${CYAN}rm -f ~/.local/bin/go2${NC}"
    printf '\n'
fi

# Function to remove go2 configuration using markers
remove_go2_markers() {
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

# Remove alias from shell config
if [ -n "$SHELL_RC" ] && [ -f "$SHELL_RC" ]; then
    if grep -q "alias go2=" "$SHELL_RC" 2>/dev/null || grep -q "$GO2_MARKER_START" "$SHELL_RC" 2>/dev/null; then
        printf '%b\n' "${CYAN}Removing go2 from ${SHELL_RC}...${NC}"
        
        # Create backup
        cp "$SHELL_RC" "${SHELL_RC}.go2.bak.$(date +%Y%m%d_%H%M%S)"
        
        # Try marker-based removal first
        if grep -q "$GO2_MARKER_START" "$SHELL_RC" 2>/dev/null; then
            remove_go2_markers "$SHELL_RC"
        fi
        
        # Also remove any legacy format entries
        if grep -q "alias go2=" "$SHELL_RC" 2>/dev/null; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' '/alias go2=/d' "$SHELL_RC"
                sed -i '' '/# go2 SSH Management System$/d' "$SHELL_RC"
            else
                sed -i '/alias go2=/d' "$SHELL_RC"
                sed -i '/# go2 SSH Management System$/d' "$SHELL_RC"
            fi
        fi
        
        printf '%b\n' "${GREEN}✓${NC} go2 removed from ${SHELL_RC}"
    else
        printf '%b\n' "${YELLOW}No go2 alias found in ${SHELL_RC}${NC}"
    fi
fi

# Check for symlink
if [ -L "$HOME/.local/bin/go2" ]; then
    printf '%b\n' "${CYAN}Removing symlink ~/.local/bin/go2...${NC}"
    rm -f "$HOME/.local/bin/go2"
    printf '%b\n' "${GREEN}✓${NC} Symlink removed"
fi

printf '\n'
printf '%b\n' "${GREEN}=== Uninstallation Complete! ===${NC}"
printf '\n'
printf '%s\n' "The go2 alias has been removed from your shell configuration."
printf '\n'
printf '%s\n' "To complete the uninstallation, you can:"
printf '%b\n' "  1. Delete the go2 directory: ${YELLOW}rm -rf \"${SCRIPT_DIR}\"${NC}"
if [ -n "$SHELL_RC" ]; then
    printf '%b\n' "  2. Reload your shell: ${YELLOW}source \"${SHELL_RC}\"${NC}"
fi
printf '\n'
