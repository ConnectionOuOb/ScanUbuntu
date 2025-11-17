#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo or as root"
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "Usage: $0 <component> [component ...]"
    exit 1
fi

APT_UPDATED=0
COMPLETED=()
FAILED=()
export DEBIAN_FRONTEND=noninteractive

apt_update_once() {
    if [ $APT_UPDATED -eq 0 ]; then
        apt-get update
        APT_UPDATED=1
    fi
}

install_package() {
    local package="$1"
    if dpkg -s "$package" >/dev/null 2>&1; then
        echo "$package already installed"
        return 0
    fi
    apt_update_once
    apt-get install -y "$package"
}

enable_service() {
    local service="$1"
    systemctl enable --now "$service"
}

configure_component() {
    local component="$1"
    case "$component" in
        ufw)
            install_package ufw || return 1
            ufw --force enable || return 1
            ufw allow 22/tcp >/dev/null 2>&1
            return 0
            ;;
        unattended-upgrades)
            install_package unattended-upgrades || return 1
            cat <<'CFG' > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
CFG
            enable_service unattended-upgrades || return 1
            return 0
            ;;
        ssh)
            install_package openssh-server || return 1
            if systemctl list-unit-files | grep -q '^sshd.service'; then
                systemctl enable --now sshd || systemctl enable --now ssh || return 1
            else
                systemctl enable --now ssh || return 1
            fi
            return 0
            ;;
        fail2ban)
            install_package fail2ban || return 1
            enable_service fail2ban || return 1
            return 0
            ;;
        apparmor)
            install_package apparmor || return 1
            install_package apparmor-utils || true
            install_package apparmor-profiles || true
            enable_service apparmor || return 1
            return 0
            ;;
        auditd)
            install_package auditd || return 1
            enable_service auditd || return 1
            return 0
            ;;
        rkhunter)
            install_package rkhunter || return 1
            return 0
            ;;
        chkrootkit)
            install_package chkrootkit || return 1
            return 0
            ;;
        iproute2)
            install_package iproute2 || return 1
            return 0
            ;;
        ssh-log-monitoring)
            install_package rsyslog || return 1
            enable_service rsyslog || return 1
            touch /var/log/auth.log
            chown syslog:adm /var/log/auth.log
            chmod 640 /var/log/auth.log
            return 0
            ;;
        *)
            echo "Unknown component: $component"
            return 1
            ;;
    esac
}

for component in "$@"; do
    echo "Applying fixes for $component"
    if configure_component "$component"; then
        COMPLETED+=("$component")
    else
        FAILED+=("$component")
    fi
    echo
done

echo "Completed components:"
if [ ${#COMPLETED[@]} -gt 0 ]; then
    for item in "${COMPLETED[@]}"; do
        echo "  - $item"
    done
else
    echo "  (none)"
fi

echo

echo "Failed components:"
if [ ${#FAILED[@]} -gt 0 ]; then
    for item in "${FAILED[@]}"; do
        echo "  - $item"
    done
else
    echo "  (none)"
fi
