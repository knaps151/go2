# go2 - SSH Connection Manager

> **Quickly connect to your servers with simple aliases. No more remembering IP addresses, usernames, or typing long SSH commands.**

`go2` is a lightweight, cross-platform SSH management system that lets you connect to your servers using memorable aliases. Just type `go2 server-name` and you're connected. Perfect for developers, sysadmins, and anyone who manages multiple servers.

[![Platform Support](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-blue)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()

---

## ✨ Features

- 🚀 **Lightning Fast** - Connect to servers instantly with short aliases
- 🔐 **Multiple Auth Methods** - Support for SSH keys, passwords, and custom ports
- 🎨 **Beautiful Terminal UI** - Color-coded output for better readability
- ➕ **Interactive Setup** - Add servers easily with `go2 add` command
- 📝 **Simple Configuration** - Plain text config file, easy to edit and version control
- 🔒 **Secure by Default** - Proper file permissions (600) and no auto-accepting of unknown host keys
- 🌍 **Cross-Platform** - Works on macOS, Linux, and Windows (WSL)
- ⚡ **Minimal Dependencies** - Uses standard Unix tools (bash, ssh), with optional `expect` for password auth

---

## 🎯 Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/knaps151/go2.git
cd go2

# Run the installation script
./install.sh

# Reload your shell
source ~/.zshrc  # macOS/Linux with zsh
# or
source ~/.bash_profile  # macOS with bash
# or
source ~/.bashrc  # Linux/WSL with bash
```

**That's it!** The installer will:
- ✅ Make scripts executable
- ✅ Add the `go2` alias to your shell
- ✅ Set up secure file permissions (600 for config)
- ✅ Check for optional dependencies

### Your First Server

```bash
# Add a server interactively
go2 add

# Connect to it
go2 my-server

# List all servers
go2 list
```

---

## 📋 Requirements

| Requirement | macOS | Linux | Windows (WSL) |
|------------|-------|-------|---------------|
| **Bash** | ✅ Pre-installed | ✅ Pre-installed | ✅ Pre-installed |
| **SSH** | ✅ Pre-installed | ✅ Pre-installed | ✅ Available |
| **expect** (optional) | ⚠️ May need install | ⚠️ May need install | ⚠️ May need install |

**Note:** `expect` is only required for automatic password entry. Without it, password authentication falls back to the standard interactive SSH prompt.

**Installing `expect`:**
- **macOS**: `brew install expect`
- **Linux (Debian/Ubuntu)**: `sudo apt-get install expect`
- **Linux (RHEL/CentOS)**: `sudo yum install expect`
- **Windows (WSL)**: `sudo apt-get install expect`

---

## 🚀 Usage

### Basic Commands

```bash
# Connect to a server
go2 server-name

# Add a new server (interactive)
go2 add

# List all configured servers
go2 list
# or simply
go2

# Show help
go2 help
```

### Real-World Examples

```bash
# Connect to your web server
go2 web1

# Connect to database server on custom port
go2 db-prod

# Add a new staging server
go2 add
# Follow the prompts...

# See all your servers at a glance
go2 list
```

---

## ⚙️ Configuration

### Adding Servers

#### Method 1: Interactive (Recommended)

```bash
go2 add
```

The interactive wizard will guide you through:
- Server name (alias)
- Hostname or IP address
- Username
- Port (defaults to 22)
- Authentication method (SSH key, password, or default)
- Additional SSH options

#### Method 2: Manual Configuration

Edit `servers.conf` directly:

```bash
# Format: name|host|user|port|key_file|password|options
web1|192.168.1.100|admin|22|~/.ssh/id_rsa||
db-server|db.example.com|root|2222|~/.ssh/db_key||
prod|prod.example.com|deploy|22||mypassword|
```

**Configuration Fields:**
- `name` - Short alias to use with `go2` command (letters, numbers, dots, dashes, underscores only)
- `host` - Server hostname or IP address
- `user` - SSH username
- `port` - SSH port (default: 22, must be a valid number 1-65535)
- `key_file` - Path to SSH private key (optional)
- `password` - SSH password (optional, **stored in plain text**)
- `options` - Additional SSH options (optional)

**Example Configurations:**

```bash
# SSH key authentication
web1|192.168.1.100|admin|22|~/.ssh/id_rsa||

# Custom port with SSH key
db-server|db.example.com|root|2222|~/.ssh/db_key||

# Password authentication (not recommended for production)
prod|prod.example.com|deploy|22||mypassword|

# With custom SSH options
staging|staging.example.com|deploy|22|~/.ssh/key||-o ServerAliveInterval=60

# Default SSH keys
test|test.example.com|user|22|||
```

---

## 🔐 Security

### Best Practices

1. **Use SSH Keys** - Prefer SSH key authentication over passwords
2. **Restrict Permissions** - The installer sets `chmod 600` on `servers.conf` automatically
3. **Version Control** - The `servers.conf` file is excluded from git (via `.gitignore`)
4. **Password Storage** - If you must use passwords, they're stored in plain text. Consider using SSH keys instead.
5. **Host Key Verification** - go2 does NOT auto-accept unknown host keys; you must verify them manually

### File Permissions

The installer and go2 automatically set secure permissions:
```bash
chmod 600 servers.conf  # Read/write for owner only
chmod +x go2.sh          # Executable
```

If the config file has insecure permissions, go2 will display a warning.

---

## 🌍 Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **macOS** | ✅ Fully Supported | Tested on Bash 3.2+ and Zsh |
| **Linux** | ✅ Fully Supported | Works on all major distributions |
| **Windows (WSL)** | ✅ Fully Supported | Same as Linux |
| **Windows (Git Bash)** | ⚠️ Partial | May require manual alias setup |

---

## 🔧 Advanced Usage

### Password Authentication

When using password authentication, `go2` uses `expect` for automatic password entry. If `expect` isn't available, it falls back to an interactive prompt.

**Automatic Password Entry:**
- Requires `expect` to be installed
- Passwords are passed securely via environment variable
- No manual typing required

**Interactive Fallback:**
- If `expect` isn't available
- You'll be prompted to enter the password manually
- Still works, just requires manual input

### Custom SSH Options

You can add any SSH options to your server configuration:

```bash
# Keep connection alive
-o ServerAliveInterval=60

# Custom timeout
-o ConnectTimeout=10
```

---

## 🗑️ Uninstallation

To remove `go2` from your system:

```bash
cd /path/to/go2
./uninstall.sh
```

This will:
- Remove the `go2` alias from your shell configuration
- Create a backup of your shell config file

You can then delete the `go2` directory if desired:
```bash
rm -rf /path/to/go2
```

---

## 📝 Notes & Tips

- **Path Expansion**: The script automatically expands `~` in key file paths to your home directory
- **Missing Keys**: If a key file is specified but not found, the script falls back to default SSH keys
- **Empty Fields**: Leave empty fields empty (use `||` for empty fields in config)
- **Comments**: Lines starting with `#` are treated as comments
- **Duplicate Servers**: The script will prompt to overwrite if you try to add a server that already exists
- **Config Location**: The config file is stored in the same directory as `go2.sh`
- **Line Endings**: The config file supports both Unix (LF) and Windows (CRLF) line endings

---

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest new features
- Submit pull requests
- Improve documentation

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

## 🙏 Acknowledgments

Built with ❤️ for developers and sysadmins who value simplicity and efficiency.

**Made with:** Bash, SSH, and a lot of terminal love.

---

**Questions? Issues?** [Open an issue](https://github.com/knaps151/go2/issues) on GitHub!
