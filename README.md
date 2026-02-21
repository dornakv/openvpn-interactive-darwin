# OpenVPN Interactive Helper on macOS

A simple interactive utility for managing OpenVPN profiles and credentials on macOS.

## Features
- Store OpenVPN credentials securely in macOS Keychain
- Select and connect to OpenVPN profiles interactively
- Supports profile storage in XDG_CONFIG_HOME/openvpn/profiles or ~/openvpn/profiles
- Add/remove credentials via command line

## Usage
- `sudo openvpn-interactive-darwin.sh setup` — Add credentials to Keychain
- `sudo openvpn-interactive-darwin.sh remove-setup` — Remove credentials from Keychain
- `sudo openvpn-interactive-darwin.sh` — Select and connect to a profile interactively
- Use `--profile <path>` to specify a profile directly

## Profile Location
- Profiles are loaded from:
  - `$XDG_CONFIG_HOME/openvpn/profiles` (if set)
  - `~/openvpn/profiles` (otherwise)

## Requirements
- OpenVPN (cli) installed
```
brew install openvpn
```
