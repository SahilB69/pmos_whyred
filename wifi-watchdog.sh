#!/bin/sh

SSID="Snorlax 5G"
LOG="/var/log/wifi-watchdog.log"
NMCLI="/usr/bin/nmcli"
GREP="/bin/grep"

# Ensure log file exists
[ -f "$LOG" ] || {
    touch "$LOG"
    chmod 644 "$LOG"
}

# Check if SSID is active
if ! $NMCLI -t -f NAME,DEVICE connection show --active | $GREP -q "^$SSID:"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') | reconnecting $SSID" >> "$LOG"
    $NMCLI connection up "$SSID" >> "$LOG" 2>&1
fi
