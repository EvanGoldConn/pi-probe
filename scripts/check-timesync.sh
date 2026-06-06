#!/bin/bash
# On SSH login, check if system clock is NTP synced.
# If not synced, warn operator to run pi-sync-time from Mac.

if timedatectl status | grep -q "System clock synchronized: yes"; then
    return 0
fi

echo ""
echo "*** System clock not NTP synced ***"
echo "*** Option 1: Run pi-sync-time from your Mac ***"
echo "*** Option 2: From Mac terminal: ssh -i ~/.ssh/id_ed25519_github_old kali@192.168.4.1 \"sudo date -s '\$(date -u \"+%Y-%m-%d %H:%M:%S\")'\" ***"
echo ""
