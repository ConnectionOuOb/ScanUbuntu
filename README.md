# ScanUbuntu

Simple toolkit to audit and harden Ubuntu hosts with minimal effort.

## Scripts

| Script | Purpose | Typical Usage |
| --- | --- | --- |
| `scan.sh` | Runs nine security checks (UFW, unattended upgrades, SSH, Fail2ban, AppArmor, Auditd, rootkit tools, open ports, SSH auth logs) and prints enabled vs missing controls, plus a ready-to-run fix command for any gaps. | `sudo ./scan.sh` |
| `fix.sh` | Installs, configures, and enables the components named on the command line (e.g., `ufw`, `fail2ban`, `auditd`, `rkhunter`, `chkrootkit`, `unattended-upgrades`, `ssh`, `apparmor`, `iproute2`, `ssh-log-monitoring`). | `sudo ./fix.sh <component ...>` |
| `firewall.sh` | Ensures SSH is allowed, enumerates current listening ports via `ss`, and interactively lets you add UFW rules per service before optionally enabling the firewall. | `sudo ./firewall.sh` |

## Recommended Flow

1. `sudo ./scan.sh` to understand the current security posture.
2. Review the suggested `fix.sh` command and run it (optionally with additional components).
3. `sudo ./firewall.sh` to confirm firewall coverage for every required service.

All scripts are Bash-based and assume `sudo` privileges.
