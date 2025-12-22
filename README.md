# SSH Management System - go2

A simple SSH connection management system that allows you to quickly connect to your servers using short aliases.

## Features

- Quick SSH connections using server aliases
- Support for custom ports, SSH keys, password authentication, and additional options
- Interactive server addition via `go2 add` command
- Easy-to-edit configuration file
- Color-coded terminal output
- Server listing with `go2 list` or `go2`
- One-command installation script

## Platform Support

✅ **Fully Supported:**
- **macOS** (tested and optimized)
- **Linux** (Ubuntu, Debian, CentOS, Fedora, etc.)
- **Windows** (via WSL - Windows Subsystem for Linux)

⚠️ **Partial Support:**
- **Windows** (Git Bash or Cygwin - may require manual setup)

## Requirements

- **Bash** (usually pre-installed on macOS and Linux, available on Windows via WSL/Git Bash)
- **SSH client** (usually pre-installed on macOS and Linux, available on Windows)
- **`expect`** (for password authentication - usually pre-installed on macOS and Linux)
  - Install on Linux: `apt-get install expect` or `yum install expect`
  - Install on macOS: Usually pre-installed, or `brew install expect`
  - Install on Windows (WSL): `apt-get install expect`
- **Git** (for cloning from GitHub)

## Quick Installation

### From GitHub:

```bash
# Clone the repository
git clone https://github.com/yourusername/connect.git
cd connect

# Run the installation script
./install.sh

# Reload your shell configuration
source ~/.zshrc  # or ~/.bashrc for bash users
```

That's it! The installation script will:
- Make the go2 script executable
- Detect your shell (zsh/bash) and add the `go2` alias automatically
- Create `servers.conf` from example if it doesn't exist
- Set proper permissions on the config file
- Check for required dependencies (`expect` for password auth)

### Windows Users (WSL):

If you're using Windows Subsystem for Linux (WSL), the installation works the same:

```bash
# In your WSL terminal
git clone https://github.com/yourusername/connect.git
cd connect
./install.sh
source ~/.bashrc  # WSL typically uses bash
```

### Windows Users (Git Bash):

Git Bash should work, but you may need to manually add the alias if the install script doesn't detect your shell correctly.

## Manual Setup

If you prefer to set up manually:

### 1. Make the script executable

```bash
chmod +x go2.sh
```

### 2. Create an alias

Add the following line to your shell configuration file:

**For Zsh (default on macOS):**
```bash
echo 'alias go2="bash /path/to/connect/go2.sh"' >> ~/.zshrc
source ~/.zshrc
```

**For Bash:**
```bash
echo 'alias go2="bash /path/to/connect/go2.sh"' >> ~/.bashrc
source ~/.bashrc
```

**Note:** Replace `/path/to/connect` with the actual path where you cloned/downloaded the repository.

### 3. Configure your servers

You can add servers in two ways:

#### Option A: Interactive addition (Recommended)
```bash
go2 add
```

This will guide you through adding a server interactively.

#### Option B: Manual configuration

Edit the `servers.conf` file and add your server configurations:

```
server-name|hostname|username|port|key-file|password|options
```

**Example configurations:**

```
# Simple connection with SSH key
web1|192.168.1.100|admin|22|~/.ssh/id_rsa||

# Custom port
db-server|db.example.com|root|2222|~/.ssh/db_key||

# With password authentication (WARNING: stored in plain text!)
prod|prod.example.com|deploy|22||mypassword|

# With additional SSH options
staging|staging.example.com|deploy|22|~/.ssh/prod_key||-o ServerAliveInterval=60

# Without key file (uses default SSH keys)
test|test.example.com|user|22|||
```

**Configuration format:**
- `name`: Short name to use with `go2` command
- `host`: Server hostname or IP address
- `user`: SSH username
- `port`: SSH port (default: 22, can be omitted)
- `key_file`: Path to SSH private key (optional, can be omitted)
- `password`: SSH password (optional, can be omitted - **WARNING: stored in plain text!**)
- `options`: Extra SSH options (optional, can be omitted)

**Security Note:** Storing passwords in plain text is a security risk. Consider using SSH keys instead. If you must use passwords, ensure the config file has restricted permissions:
```bash
chmod 600 servers.conf
```

## Usage

### Connect to a server:
```bash
go2 server-name
```

### Add a new server interactively:
```bash
go2 add
```

### List available servers:
```bash
go2 list
# or simply
go2
```

## Examples

```bash
# Connect to web1 server
go2 web1

# Connect to database server
go2 db-server

# Add a new server interactively
go2 add

# List all configured servers
go2 list
```

## Password Authentication

If you configure a server with a password, the script uses `expect` (usually pre-installed on macOS and Linux) for automatic password entry. If `expect` is not available, it will fall back to an interactive password prompt.

**Note:** `expect` is typically pre-installed on macOS and most Linux distributions. If you need to install it:
- **macOS**: Usually pre-installed, or `brew install expect`
- **Linux (Debian/Ubuntu)**: `sudo apt-get install expect`
- **Linux (RHEL/CentOS/Fedora)**: `sudo yum install expect` or `sudo dnf install expect`
- **Windows (WSL)**: `sudo apt-get install expect`

## Uninstallation

To remove go2 from your system:

```bash
cd /path/to/connect
./uninstall.sh
```

This will:
- Remove the `go2` alias from your shell configuration
- Create a backup of your shell config file

You can then manually delete the go2 directory if desired.

## Notes

- The script will automatically expand `~` in key file paths to your home directory
- If a key file is specified but not found, the script will continue without it (using default SSH keys)
- Empty fields in the config file should be left empty (use `||` for empty fields)
- Lines starting with `#` are treated as comments
- When using password authentication, passwords are stored in plain text. Use SSH keys for better security
- The script will prompt to overwrite if you try to add a server that already exists
- The `servers.conf` file is excluded from git (via `.gitignore`) to protect your credentials

