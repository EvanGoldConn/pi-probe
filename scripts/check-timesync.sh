#!/bin/bash
# Warn operator if system clock hasn't been synced via NTP.
# Relevant when Pi booted into hotspot mode with no internet access.

if ! timedatectl status | grep -q "NTP service: active"; then
    echo ""
    echo "*** WARNING: System clock not NTP synced ***"
    echo "*** Run: sudo fix-time                    ***"
    echo ""
fi
