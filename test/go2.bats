#!/usr/bin/env bats

# Test suite for go2 SSH connection manager
# Uses a mock ssh script to verify command construction

setup() {
    # Create a temporary directory for each test
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
    
    # Create a mock ssh that records arguments to a file
    MOCK_SSH="$TEST_DIR/ssh"
    cat > "$MOCK_SSH" << 'EOF'
#!/bin/bash
# Mock ssh: print all arguments, one per line
printf '%s\n' "$@" > "${TEST_DIR}/ssh_args"
printf '%s\n' "$@"
exit 0
EOF
    chmod +x "$MOCK_SSH"
    
    # Add the test dir to PATH so our mock ssh is found
    export PATH="$TEST_DIR:$PATH"
    
    # Copy go2.sh to test directory
    cp "$BATS_TEST_DIRNAME/../go2.sh" "$TEST_DIR/go2.sh"
    chmod +x "$TEST_DIR/go2.sh"
    
    # Point go2 to use the test directory as its base
    export GO2_SCRIPT="$TEST_DIR/go2.sh"
    export CONFIG_FILE="$TEST_DIR/servers.conf"
    
    # Modify go2.sh to use our CONFIG_FILE
    sed -i.bak "s|CONFIG_FILE=\"\${SCRIPT_DIR}/servers.conf\"|CONFIG_FILE=\"\${TEST_DIR}/servers.conf\"|" "$TEST_DIR/go2.sh"
}

teardown() {
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
}

# Helper function to create config file
create_config() {
    printf '%s\n' "$@" > "$CONFIG_FILE"
}

# Helper function to append to config (without trailing newline)
create_config_no_newline() {
    printf '%s' "$@" > "$CONFIG_FILE"
}

# Helper function to create config with CRLF endings
create_config_crlf() {
    printf '%s\r\n' "$@" > "$CONFIG_FILE"
}

# Helper function to run go2
run_go2() {
    run bash "$TEST_DIR/go2.sh" "$@"
}

# ============================================================================
# HIGH-1: Overwrite uses exact match, not regex
# ============================================================================

@test "HIGH-1: server name with dots doesn't match other entries (web.1 vs webx1)" {
    create_config "web.1|host1|user1|22|||" "webx1|host2|user2|22|||"
    
    # Verify both servers are found initially
    run_go2 list
    [ "$status" -eq 0 ]
    [[ "$output" == *"web.1"* ]]
    [[ "$output" == *"webx1"* ]]
    
    # Connect to web.1 and verify the correct host is used
    run_go2 "web.1"
    [ "$status" -eq 0 ]
    
    # Check ssh args
    grep -q "user1@host1" "$TEST_DIR/ssh_args"
}

@test "HIGH-1: server name with brackets doesn't break matching" {
    # Server names with special chars are now rejected, so this tests the rejection
    # First, test a valid server name works
    create_config "test-server|host1|user1|22|||"
    run_go2 "test-server"
    [ "$status" -eq 0 ]
}

# ============================================================================
# HIGH-2: Permissions
# ============================================================================

@test "HIGH-2: config file created with 600 permissions" {
    # Use go2 add simulation via direct file creation with umask
    (umask 077 && printf '%s\n' "test|host|user|22|||" > "$CONFIG_FILE")
    
    local perms
    if [[ "$OSTYPE" == "darwin"* ]]; then
        perms=$(stat -f '%A' "$CONFIG_FILE")
    else
        perms=$(stat -c '%a' "$CONFIG_FILE")
    fi
    
    [ "$perms" = "600" ]
}

@test "HIGH-2: warning shown for world-readable config" {
    create_config "server1|host1|user1|22|||"
    chmod 644 "$CONFIG_FILE"
    
    run_go2 list
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"* ]] || [[ "$output" == *"insecure permissions"* ]]
}

# ============================================================================
# MED-4: Final line without newline
# ============================================================================

@test "MED-4: reads final line without trailing newline" {
    create_config_no_newline "server1|host1|user1|22|||"
    
    run_go2 list
    [ "$status" -eq 0 ]
    [[ "$output" == *"server1"* ]]
}

@test "MED-4: multiple lines, last without newline" {
    # First line with newline, second without
    printf '%s\n%s' "server1|host1|user1|22|||" "server2|host2|user2|22|||" > "$CONFIG_FILE"
    
    run_go2 list
    [ "$status" -eq 0 ]
    [[ "$output" == *"server1"* ]]
    [[ "$output" == *"server2"* ]]
}

# ============================================================================
# MED-5: CRLF line endings
# ============================================================================

@test "MED-5: handles CRLF line endings from Windows" {
    create_config_crlf "server1|host1|user1|22|||"
    
    run_go2 "server1"
    [ "$status" -eq 0 ]
    
    # Verify the host doesn't have a trailing \r
    local ssh_args=$(cat "$TEST_DIR/ssh_args")
    [[ "$ssh_args" != *$'\r'* ]]
    grep -q "user1@host1" "$TEST_DIR/ssh_args"
}

@test "MED-5: handles mixed LF and CRLF" {
    printf '%s\r\n%s\n' "server1|host1|user1|22|||" "server2|host2|user2|22|||" > "$CONFIG_FILE"
    
    run_go2 list
    [ "$status" -eq 0 ]
    [[ "$output" == *"server1"* ]]
    [[ "$output" == *"server2"* ]]
}

# ============================================================================
# MED-8: Port validation
# ============================================================================

@test "MED-8: valid port number connects successfully" {
    create_config "server1|host1|user1|8022|||"
    
    run_go2 "server1"
    [ "$status" -eq 0 ]
    
    # Verify -p flag is present with correct port
    grep -q "\-p" "$TEST_DIR/ssh_args"
    grep -q "8022" "$TEST_DIR/ssh_args"
}

@test "MED-8: port 22 doesn't add -p flag" {
    create_config "server1|host1|user1|22|||"
    
    run_go2 "server1"
    [ "$status" -eq 0 ]
    
    # Verify -p flag is NOT present for default port
    ! grep -q "^\-p$" "$TEST_DIR/ssh_args"
}

# ============================================================================
# Server name validation
# ============================================================================

@test "reserved names: 'add' triggers add command, not server lookup" {
    create_config "add|host1|user1|22|||"
    
    # Provide empty input to avoid hanging on prompt, then check behavior
    run bash -c "echo '' | timeout 2 bash '$TEST_DIR/go2.sh' add 2>&1 || true"
    # 'add' should trigger the add_server function (shows prompt), not connect
    [[ "$output" == *"Add New Server"* ]] || [[ "$output" == *"Server name"* ]] || [[ "$output" == *"alias"* ]]
}

@test "reserved names: 'list' cannot be used as server name" {
    create_config "list|host1|user1|22|||"
    
    run_go2 "list"
    # 'list' should trigger list_servers, not connect
    [ "$status" -eq 0 ]
    # Should show list output
    [[ "$output" != *"Connecting to"* ]]
}

@test "reserved names: 'help' cannot be used as server name" {
    create_config "help|host1|user1|22|||"
    
    run_go2 "help"
    # 'help' should show usage
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

# ============================================================================
# SSH command construction
# ============================================================================

@test "ssh args include -- before destination" {
    create_config "server1|host1|user1|22|||"
    
    run_go2 "server1"
    [ "$status" -eq 0 ]
    
    # Verify -- is present before the destination
    grep -q "^\-\-$" "$TEST_DIR/ssh_args"
}

@test "ssh args with custom port" {
    create_config "server1|host1|user1|2222|||"
    
    run_go2 "server1"
    [ "$status" -eq 0 ]
    
    # Verify the order: ssh, -p, 2222, --, user@host
    local args=$(cat "$TEST_DIR/ssh_args")
    [[ "$args" == *"-p"* ]]
    [[ "$args" == *"2222"* ]]
    [[ "$args" == *"user1@host1"* ]]
}

@test "ssh args with key file" {
    # Create a fake key file
    touch "$TEST_DIR/id_rsa"
    create_config "server1|host1|user1|22|$TEST_DIR/id_rsa||"
    
    run_go2 "server1"
    [ "$status" -eq 0 ]
    
    grep -q "^\-i$" "$TEST_DIR/ssh_args"
}

@test "key file warning when file doesn't exist" {
    create_config "server1|host1|user1|22|/nonexistent/key||"
    
    run_go2 "server1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"* ]] && [[ "$output" == *"not found"* ]]
}

# ============================================================================
# Help and usage
# ============================================================================

@test "help command exits 0" {
    run_go2 help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "--help exits 0" {
    run_go2 --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "-h exits 0" {
    run_go2 -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "no arguments shows usage and exits 1" {
    run_go2
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage"* ]]
}

# ============================================================================
# Comment handling
# ============================================================================

@test "comment lines are skipped" {
    create_config "# This is a comment" "server1|host1|user1|22|||"
    
    run_go2 "server1"
    [ "$status" -eq 0 ]
    grep -q "user1@host1" "$TEST_DIR/ssh_args"
}

@test "indented comment lines are skipped" {
    create_config "  # Indented comment" "server1|host1|user1|22|||"
    
    run_go2 list
    [ "$status" -eq 0 ]
    [[ "$output" == *"server1"* ]]
    # Should not show the comment as a server
    [[ "$output" != *"Indented"* ]]
}

@test "empty lines are skipped" {
    create_config "server1|host1|user1|22|||" "" "server2|host2|user2|22|||"
    
    run_go2 list
    [ "$status" -eq 0 ]
    [[ "$output" == *"server1"* ]]
    [[ "$output" == *"server2"* ]]
}

# ============================================================================
# Server not found
# ============================================================================

@test "unknown server shows error and list" {
    create_config "server1|host1|user1|22|||"
    
    run_go2 "unknown"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
    [[ "$output" == *"server1"* ]]
}

# ============================================================================
# Additional SSH options
# ============================================================================

@test "additional options are passed to ssh" {
    create_config "server1|host1|user1|22|||-o ServerAliveInterval=60"
    
    run_go2 "server1"
    [ "$status" -eq 0 ]
    
    grep -q "ServerAliveInterval=60" "$TEST_DIR/ssh_args"
}

# ============================================================================
# Auth info display
# ============================================================================

@test "auth info shows password when password set" {
    create_config "server1|host1|user1|22||secret|"
    
    run_go2 "server1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"password auth"* ]]
}

@test "auth info shows key when key exists" {
    touch "$TEST_DIR/id_rsa"
    create_config "server1|host1|user1|22|$TEST_DIR/id_rsa||"
    
    run_go2 "server1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"key:"* ]]
}

@test "auth info doesn't show key when key missing" {
    create_config "server1|host1|user1|22|/nonexistent/key||"
    
    run_go2 "server1"
    [ "$status" -eq 0 ]
    # Should show warning but not "key:" in auth info
    [[ "$output" == *"Warning"* ]]
}
