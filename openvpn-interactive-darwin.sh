#!/bin/bash

SVC_NAME="com.openvpninteractive"

# Check if run as root
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root (use sudo to launch it)."
    exit 1
fi

# Check if keychain is unlocked (required for SSH sessions)
check_keychain() {
    local keychain
    keychain=$(security default-keychain | tr -d '[:space:]"')
    if ! security show-keychain-info "$keychain" 2>/dev/null; then
        echo "Error: Keychain is locked. Run 'security unlock-keychain $keychain' first."
        exit 1
    fi
}

# parse accounts from keychain for given service name
get_accounts() {
    local svc_name="$1"
    security dump-keychain | awk -v RS='keychain: ' -v svc_name="$svc_name" '
    $0 ~ ("svce\"<blob>=\"" svc_name "\"") {
        if (match($0, /\"acct\"<blob>=\"[^\"]+\"/)) {
            val = substr($0, RSTART, RLENGTH)
            gsub(/\"acct\"<blob>=\"|\"/, "", val)
            print val
        }
    }'
}

show_help() {
    echo "Usage: $0 <subcommand> [options]"
    echo ""
    echo "Subcommands:"
    echo "  start                 Start the OpenVPN daemon"
    echo "    --profile, -p <path>  Specify path to .ovpn profile file"
    echo "    --user, -u <username> Specify user/account for OpenVPN (skip selection)"
    echo "    --dry-run             Show what would be done without making changes"
    echo ""
    echo "  stop                  Stop the running OpenVPN daemon"
    echo "    --dry-run             Show what would be done without making changes"
    echo ""
    echo "  setup                 Setup username and password for OpenVPN (saved to keychain)"
    echo "    --dry-run             Show what would be done without making changes"
    echo ""
    echo "  setup-remove          Remove credentials from keychain"
    echo "    --dry-run             Show what would be done without making changes"
    echo ""
    echo "  state                 Check if VPN is running (shows profile path)"
}

setup() {
    check_keychain
    # Check for --dry-run
    DRY_RUN=false
    for arg in "$@"; do
        [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
    done
    echo "Username:"
    read -r VPN_USER
    echo "Password:"
    read -s -r VPN_PASS
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would save credentials for user '$VPN_USER' to keychain as '$SVC_NAME'."
    else
        security add-generic-password -s "$SVC_NAME" -a "$VPN_USER" -w "$VPN_PASS" -U
        echo "Credentials saved to keychain as '$SVC_NAME'."
    fi
    unset VPN_USER
    unset VPN_PASS
}

setup-remove() {
    check_keychain
    # Check for --dry-run
    DRY_RUN=false
    for arg in "$@"; do
        [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
    done
    ACCOUNTS=($(get_accounts "$SVC_NAME"))
    if [[ ${#ACCOUNTS[@]} -eq 0 ]]; then
        echo "No $SVC_NAME credentials found in keychain."
        exit 0
    fi
    echo "Available $SVC_NAME users to remove:"
    for i in "${!ACCOUNTS[@]}"; do
        echo "$((i+1)). ${ACCOUNTS[$i]}"
    done
    read -p "Select user to remove [1]: " USER_INDEX
    USER_INDEX=${USER_INDEX:-1}
    if ! [[ $USER_INDEX =~ ^[0-9]+$ ]] || (( USER_INDEX < 1 )) || (( USER_INDEX > ${#ACCOUNTS[@]} )); then
        echo "Invalid selection. Exiting."
        exit 1
    fi
    USER="${ACCOUNTS[$((USER_INDEX-1))]}"
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would remove credentials for user: $USER"
    else
        security delete-generic-password -s "$SVC_NAME" -a "$USER"
        echo "Removed credentials for user: $USER"
    fi
}

start() {
    # Check if already running
    if pgrep -f "openvpn.*--daemon $SVC_NAME" > /dev/null 2>&1; then
        echo "OpenVPN daemon '$SVC_NAME' is already running. Use '$0 stop' to stop it."
        exit 1
    fi

    check_keychain
    PROFILE_ARG=""
    USER_ARG=""
    DRY_RUN=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile|-p)
                PROFILE_ARG="$2"
                shift 2
                ;;
            --user|-u)
                USER_ARG="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ -n "$PROFILE_ARG" ]]; then
        CONFIG_PATH="$PROFILE_ARG"
    else
        # List profiles
        if [[ ${#PROFILES[@]} -eq 0 || "${PROFILES[0]}" == "${PROFILE_DIR}/*.ovpn" ]]; then
            echo "No OpenVPN profiles found in $PROFILE_DIR."
            exit 1
        fi
        echo "Available OpenVPN profiles:"
        for i in "${!PROFILES[@]}"; do
            echo "$((i+1)). $(basename "${PROFILES[$i]}")"
        done

        # Prompt user to select
        read -p "Select profile [1]: " PROFILE_INDEX
        PROFILE_INDEX=${PROFILE_INDEX:-1}
        if ! [[ $PROFILE_INDEX =~ ^[0-9]+$ ]] || (( PROFILE_INDEX < 1 )) || (( PROFILE_INDEX > ${#PROFILES[@]} )); then
            echo "Invalid selection. Exiting."
            exit 1
        fi
        CONFIG_PATH="${PROFILES[$((PROFILE_INDEX-1))]}"
    fi

    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "Error: Could not find config file at $CONFIG_PATH"
        exit 1
    fi

    ACCOUNTS=($(get_accounts "$SVC_NAME"))
    if [[ ${#ACCOUNTS[@]} -eq 0 ]]; then
        echo "No $SVC_NAME credentials found in keychain. Run $0 setup to add."
        exit 1
    fi

    # If --user/-u specified, use it directly
    if [[ -n "$USER_ARG" ]]; then
        USER="$USER_ARG"
        if ! [[ " ${ACCOUNTS[*]} " =~ " $USER " ]]; then
            echo "User '$USER' not found in keychain for $SVC_NAME."
            exit 1
        fi
    else
        if [[ ${#ACCOUNTS[@]} -eq 1 ]]; then
            USER="${ACCOUNTS[0]}"
        else
            echo "Available $SVC_NAME users:"
            for i in "${!ACCOUNTS[@]}"; do
                echo "$((i+1)). ${ACCOUNTS[$i]}"
            done
            read -p "Select user [1]: " USER_INDEX
            USER_INDEX=${USER_INDEX:-1}
            if ! [[ $USER_INDEX =~ ^[0-9]+$ ]] || (( USER_INDEX < 1 )) || (( USER_INDEX > ${#ACCOUNTS[@]} )); then
                echo "Invalid selection. Exiting."
                exit 1
            fi
            USER="${ACCOUNTS[$((USER_INDEX-1))]}"
        fi
    fi
    PASS=$(security find-generic-password -s "$SVC_NAME" -a "$USER" -w)

    # Start OpenVPN connection
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would connect to VPN with:"
        echo "  Profile: $CONFIG_PATH"
        echo "  User: $USER"
        echo "  Command: openvpn --config \"$CONFIG_PATH\" --auth-user-pass <credentials>"
    else
        openvpn --config "$CONFIG_PATH" --daemon "$SVC_NAME" --auth-user-pass <(printf '%s\n%s\n' "$USER" "$PASS")
    fi
    exit 0
}

stop() {
    for arg in "$@"; do
        [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
    done
    if ! pgrep -f "openvpn.*--daemon $SVC_NAME" > /dev/null 2>&1; then
        echo "OpenVPN daemon '$SVC_NAME' is not running."
        exit 0
    fi
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would stop OpenVPN daemon '$SVC_NAME'."
    else
        pkill -f "openvpn.*--daemon $SVC_NAME"
        echo "Stopped OpenVPN daemon '$SVC_NAME'."
    fi
    exit 0
}

# Set PROFILE_DIR based on XDG_CONFIG_HOME or fallback to ~/openvpn/profiles
if [[ -n "$XDG_CONFIG_HOME" ]]; then
    PROFILE_DIR="$XDG_CONFIG_HOME/openvpn/profiles"
else
    PROFILE_DIR="$HOME/openvpn/profiles"
fi
PROFILES=("$PROFILE_DIR"/*.ovpn)

# 'setup' subcommand to add credentials to keychain
if [[ "$1" == "setup" ]]; then
    shift
    setup "$@"
    exit 0
fi

# 'setup-remove' subcommand to remove credentials from keychain
if [[ "$1" == "setup-remove" ]]; then
    shift
    setup-remove "$@"
    exit 0
fi

# 'start' subcommand to start the VPN daemon
if [[ "$1" == "start" ]]; then
    shift
    start "$@"
    exit 0
fi

# 'stop' subcommand to stop the running daemon
if [[ "$1" == "stop" ]]; then
    shift
    stop "$@"
    exit 0
fi

# 'state' subcommand to check if VPN is running
if [[ "$1" == "state" ]]; then
    PID=$(pgrep -f "openvpn.*--daemon $SVC_NAME" 2>/dev/null)
    if [[ -n "$PID" ]]; then
        CMD_LINE=$(ps -p "$PID" -o args= 2>/dev/null)
        PROFILE=$(echo "$CMD_LINE" | sed -n 's/.*--config \([^ ]*\).*/\1/p')
        echo "running: $PROFILE"
        exit 0
    else
        echo "stopped"
        exit 1
    fi
fi

# Show help if no subcommand
show_help
exit 0