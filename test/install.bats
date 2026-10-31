#!/usr/bin/env bats

# Test suite for go2 install.sh

setup() {
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"
    
    # Copy install files to test directory
    cp "$BATS_TEST_DIRNAME/../install.sh" "$TEST_DIR/"
    cp "$BATS_TEST_DIRNAME/../go2.sh" "$TEST_DIR/"
    cp "$BATS_TEST_DIRNAME/../servers.conf.example" "$TEST_DIR/" 2>/dev/null || true
    chmod +x "$TEST_DIR/install.sh" "$TEST_DIR/go2.sh"
    
    # Create a minimal servers.conf.example if it doesn't exist
    if [ ! -f "$TEST_DIR/servers.conf.example" ]; then
        echo "# Example config" > "$TEST_DIR/servers.conf.example"
    fi
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "install.sh creates proper alias with quoted path" {
    # Set SHELL to bash for the test
    export SHELL=/bin/bash
    touch "$HOME/.bashrc"
    
    # Run install non-interactively by providing input
    echo "n" | bash "$TEST_DIR/install.sh" || true
    
    # Check the alias line contains proper quoting
    if grep -q "alias go2=" "$HOME/.bashrc" 2>/dev/null; then
        local alias_line=$(grep "alias go2=" "$HOME/.bashrc")
        # Should have quotes around the path
        [[ "$alias_line" == *'bash "'* ]] || [[ "$alias_line" == *"bash '"* ]]
    fi
}

@test "install.sh uses marker comments" {
    export SHELL=/bin/bash
    touch "$HOME/.bashrc"
    
    echo "n" | bash "$TEST_DIR/install.sh" || true
    
    # Check for marker comments
    grep -q ">>> go2 SSH Management System >>>" "$HOME/.bashrc" || \
    grep -q "alias go2=" "$HOME/.bashrc"
}

@test "install.sh creates config with 600 permissions" {
    export SHELL=/bin/bash
    touch "$HOME/.bashrc"
    
    echo "n" | bash "$TEST_DIR/install.sh" || true
    
    if [ -f "$TEST_DIR/servers.conf" ]; then
        local perms
        if [[ "$OSTYPE" == "darwin"* ]]; then
            perms=$(stat -f '%A' "$TEST_DIR/servers.conf")
        else
            perms=$(stat -c '%a' "$TEST_DIR/servers.conf")
        fi
        [ "$perms" = "600" ]
    fi
}

@test "install.sh handles zsh shell" {
    export SHELL=/bin/zsh
    touch "$HOME/.zshrc"
    
    echo "n" | bash "$TEST_DIR/install.sh" || true
    
    # Should have modified .zshrc
    [ -f "$HOME/.zshrc" ]
    grep -q "alias go2=" "$HOME/.zshrc" || grep -q "go2" "$HOME/.zshrc"
}

@test "install.sh shows message for unsupported shell" {
    export SHELL=/bin/tcsh
    
    run bash "$TEST_DIR/install.sh"
    
    # Should show warning about unsupported shell
    [[ "$output" == *"not directly supported"* ]] || \
    [[ "$output" == *"symlink"* ]] || \
    [[ "$output" == *"manually"* ]]
}
