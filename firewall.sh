#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo or as root"
    exit 1
fi

if ! command -v ufw >/dev/null 2>&1; then
    echo "ufw is not installed. Run sudo ./fix.sh ufw"
    exit 1
fi

if ! command -v ss >/dev/null 2>&1; then
    echo "ss command is missing. Run sudo ./fix.sh iproute2"
    exit 1
fi

SSH_PORT=22
if [ -f /etc/ssh/sshd_config ]; then
    SSH_CFG_PORT=$(grep -E "^Port" /etc/ssh/sshd_config | tail -n 1 | awk '{print $2}')
    if [[ "$SSH_CFG_PORT" =~ ^[0-9]+$ ]]; then
        SSH_PORT=$SSH_CFG_PORT
    fi
fi

echo "Allowing SSH port ${SSH_PORT}/tcp"
ufw allow "${SSH_PORT}/tcp"

mapfile -t RAW_PORTS < <(ss -H -tuln 2>/dev/null | awk '{print $1" "$5}')

declare -A UNIQUE=()
PORT_LIST=()

for entry in "${RAW_PORTS[@]}"; do
    proto=${entry%% *}
    addr=${entry##* }
    port=${addr##*:}
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        continue
    fi
    proto_lower=$(echo "$proto" | tr '[:upper:]' '[:lower:]')
    key="${proto_lower}/${port}"
    if [ "$key" = "tcp/${SSH_PORT}" ]; then
        continue
    fi
    if [ -z "${UNIQUE[$key]+x}" ]; then
        UNIQUE[$key]=1
        PORT_LIST+=("$key")
    fi
done

if [ ${#PORT_LIST[@]} -eq 0 ]; then
    echo "No additional listening ports detected"
else
    echo "Detected listening ports:"
    for item in "${PORT_LIST[@]}"; do
        echo "  - $item"
    done
    echo
    for item in "${PORT_LIST[@]}"; do
        proto=${item%%/*}
        port=${item##*/}
        while true; do
            read -rp "Allow ${proto}/${port}? (y/N) " ans
            ans=$(echo "$ans" | tr '[:upper:]' '[:lower:]')
            case "$ans" in
                y|yes)
                    ufw allow "${port}/${proto}"
                    break
                    ;;
                n|no|"")
                    echo "Skip ${proto}/${port}"
                    break
                    ;;
                *)
                    echo "Please answer y or n"
                    ;;
            esac
        done
    done
fi

STATUS_LINE=$(ufw status | head -n 1)
if echo "$STATUS_LINE" | grep -qi "inactive"; then
    read -rp "UFW is inactive. Enable it now? (Y/n) " enable_ans
    enable_ans=$(echo "$enable_ans" | tr '[:upper:]' '[:lower:]')
    if [ -z "$enable_ans" ] || [ "$enable_ans" = "y" ] || [ "$enable_ans" = "yes" ]; then
        ufw --force enable
    else
        echo "Skipping enable step"
    fi
fi

echo
ufw status verbose
