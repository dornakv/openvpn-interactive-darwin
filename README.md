# OpenVPN Interactive Helper on macOS

A simple interactive utility for managing OpenVPN profiles and credentials on macOS.

## Features
- Store OpenVPN credentials securely in macOS Keychain
- Select and connect to OpenVPN profiles interactively
- Supports profile storage in XDG_CONFIG_HOME/openvpn/profiles or ~/openvpn/profiles
- Add/remove credentials via command line

## Usage
```
sudo openvpn-interactive-darwin.sh <subcommand> [options]
```

### Subcommands

**start** — Start the OpenVPN daemon
- `--profile, -p <path>` — Specify path to .ovpn profile file
- `--user, -u <username>` — Specify user/account for OpenVPN (skip selection)
- `--dry-run` — Show what would be done without making changes

**stop** — Stop the running OpenVPN daemon
- `--dry-run` — Show what would be done without making changes

**setup** — Add credentials to Keychain
- `--dry-run` — Show what would be done without making changes

**setup-remove** — Remove credentials from Keychain
- `--dry-run` — Show what would be done without making changes

**state** — Check if VPN is running (shows profile path if running)

## Profile Location
- Profiles are loaded from:
  - `$XDG_CONFIG_HOME/openvpn/profiles` (if set)
  - `~/openvpn/profiles` (otherwise)

## Requirements
- OpenVPN (cli) installed
```
brew install openvpn
```
