#!/bin/bash

echo "=============================="
echo " Ubuntu Security Check Tool"
echo "=============================="
echo

ENABLED_LABELS=()
DISABLED_LABELS=()
DISABLED_KEYS=()

mark_enabled() {
    ENABLED_LABELS+=("$1")
}

mark_disabled() {
    local key="$1"
    local label="$2"
    DISABLED_LABELS+=("$label")
    if [ -n "$key" ]; then
        DISABLED_KEYS+=("$key")
    fi
}

check_ufw() {
    echo "▶ 1. Checking UFW Firewall Status"
    if command -v ufw >/dev/null 2>&1; then
        STATUS=$(sudo ufw status | head -n 1)
        if echo "$STATUS" | grep -q "Status: active"; then
            mark_enabled "UFW Firewall"
            sudo ufw status verbose
        else
            mark_disabled "ufw" "UFW Firewall (inactive)"
            echo "Status: inactive"
        fi
    else
        mark_disabled "ufw" "UFW Firewall (not installed)"
        echo "UFW is not installed"
    fi
    echo
}

check_unattended_upgrades() {
    echo "▶ 2. Checking Automatic Security Updates (unattended-upgrades)"
    if command -v apt-cache >/dev/null 2>&1; then
        INSTALLED=$(apt-cache policy unattended-upgrades | grep Installed | awk '{print $2}')
        if [ "$INSTALLED" != "(none)" ] && [ -n "$INSTALLED" ]; then
            echo "Installed: $INSTALLED"
            echo "Configuration:"
            if [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
                sudo cat /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null
                mark_enabled "Unattended-upgrades"
            else
                mark_disabled "unattended-upgrades" "Unattended-upgrades (not configured)"
            fi
        else
            mark_disabled "unattended-upgrades" "Unattended-upgrades (not installed)"
            echo "Not installed"
        fi
    fi
    echo
}

check_ssh() {
    echo "▶ 3. Checking SSH Configuration"
    if [ -f /etc/ssh/sshd_config ]; then
        PERMIT_ROOT=$(grep -E "^PermitRootLogin" /etc/ssh/sshd_config | tail -n 1)
        PASSWORD_AUTH=$(grep -E "^PasswordAuthentication" /etc/ssh/sshd_config | tail -n 1)
        if [ -n "$PERMIT_ROOT" ]; then
            echo "$PERMIT_ROOT"
        fi
        if [ -n "$PASSWORD_AUTH" ]; then
            echo "$PASSWORD_AUTH"
        fi
        if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
            mark_enabled "SSH Service"
        else
            mark_disabled "ssh" "SSH Service (inactive)"
        fi
    else
        mark_disabled "ssh" "SSH Service (config not found)"
    fi
    echo
}

check_fail2ban() {
    echo "▶ 4. Checking Fail2ban Status"
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        mark_enabled "Fail2ban"
        systemctl status fail2ban --no-pager | grep Active
        sudo fail2ban-client status 2>/dev/null
    else
        mark_disabled "fail2ban" "Fail2ban (inactive or not installed)"
        echo "Status: inactive or not installed"
    fi
    echo
}

check_apparmor() {
    echo "▶ 5. Checking AppArmor Status"
    if command -v aa-status >/dev/null 2>&1; then
        if sudo aa-status >/dev/null 2>&1; then
            mark_enabled "AppArmor"
            sudo aa-status 2>/dev/null | head -n 20
        else
            mark_disabled "apparmor" "AppArmor (not active)"
        fi
    else
        mark_disabled "apparmor" "AppArmor (not installed)"
    fi
    echo
}

check_auditd() {
    echo "▶ 6. Checking Auditd"
    if systemctl is-active --quiet auditd 2>/dev/null; then
        mark_enabled "Auditd"
        systemctl status auditd --no-pager | grep Active
    else
        mark_disabled "auditd" "Auditd (inactive or not installed)"
        echo "Status: inactive or not installed"
    fi
    echo
}

check_rootkit_tools() {
    echo "▶ 7. Checking Rootkit Detection Tools (rkhunter/chkrootkit)"
    if command -v rkhunter >/dev/null 2>&1; then
        echo "- rkhunter is installed"
        mark_enabled "rkhunter"
    else
        echo "- rkhunter is not installed"
        mark_disabled "rkhunter" "rkhunter (not installed)"
    fi
    if command -v chkrootkit >/dev/null 2>&1; then
        echo "- chkrootkit is installed"
        mark_enabled "chkrootkit"
    else
        echo "- chkrootkit is not installed"
        mark_disabled "chkrootkit" "chkrootkit (not installed)"
    fi
    echo
}

check_open_ports() {
    echo "▶ 8. Checking Open Ports"
    if command -v ss >/dev/null 2>&1; then
        sudo ss -tulnp
        mark_enabled "Port Scanning (ss)"
    else
        mark_disabled "iproute2" "Port Scanning (ss not available)"
    fi
    echo
}

check_ssh_failed_logins() {
    echo "▶ 9. Checking SSH Failed Login Attempts"
    if [ -f /var/log/auth.log ]; then
        FAILED_COUNT=$(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
        echo "Failed password attempts: $FAILED_COUNT"
        mark_enabled "SSH Log Monitoring"
    else
        mark_disabled "ssh-log-monitoring" "SSH Log Monitoring (auth.log not found)"
    fi
    echo
}

check_ufw
check_unattended_upgrades
check_ssh
check_fail2ban
check_apparmor
check_auditd
check_rootkit_tools
check_open_ports
check_ssh_failed_logins

echo "=============================="
echo " Summary"
echo "=============================="
echo

if [ ${#ENABLED_LABELS[@]} -gt 0 ]; then
    echo "✓ Enabled Services/Features:"
    for item in "${ENABLED_LABELS[@]}"; do
        echo "  - $item"
    done
    echo
fi

if [ ${#DISABLED_LABELS[@]} -gt 0 ]; then
    echo "✗ Disabled/Not Installed Services/Features:"
    for item in "${DISABLED_LABELS[@]}"; do
        echo "  - $item"
    done
    echo
fi

if [ ${#DISABLED_KEYS[@]} -gt 0 ]; then
    declare -A FIX_SET=()
    FIX_ARGS=()
    for key in "${DISABLED_KEYS[@]}"; do
        if [ -n "$key" ] && [ -z "${FIX_SET[$key]}" ]; then
            FIX_SET[$key]=1
            FIX_ARGS+=("$key")
        fi
    done
    if [ ${#FIX_ARGS[@]} -gt 0 ]; then
        echo "Suggested fix command:"
        echo "  sudo ./fix.sh ${FIX_ARGS[*]}"
        echo
    fi
fi

echo "=============================="
echo " Check Complete"
echo "=============================="
