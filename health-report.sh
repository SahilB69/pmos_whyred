#!/bin/sh

# -------- Telegram Config --------
CONFIG_FILE="/home/neo/.config/telebot/bot.conf"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Telegram config not found: $CONFIG_FILE" >&2
  exit 1
fi

. "$CONFIG_FILE"


# -------- CPU Average Load (1 minute) --------
CPU_LOAD=$(/usr/bin/cut -d' ' -f1 /proc/loadavg)

LOAD_EMOJI=$(awk -v l="$CPU_LOAD" '
BEGIN {
  if (l < 1.0) print "🟢";
  else if (l < 3.0) print "🟡";
  else print "🔴";
}')

# -------- CPU Temperature --------
CPU_TEMP_RAW=$(cat /sys/class/thermal/thermal_zone0/hwmon0/temp1_input 2>/dev/null)
[ -n "$CPU_TEMP_RAW" ] && CPU_TEMP=$(awk "BEGIN { printf \"%.1f\", $CPU_TEMP_RAW/1000 }") || CPU_TEMP="N/A"

# -------- Battery --------
BAT=$(cat /sys/class/power_supply/qcom-battery/capacity 2>/dev/null || echo "N/A")
BAT_STATUS=$(cat /sys/class/power_supply/qcom-battery/status 2>/dev/null || echo "Unknown")

# -------- Battery Temperature --------
BAT_TEMP_RAW=$(cat /sys/class/power_supply/qcom-battery/temp 2>/dev/null)
[ -n "$BAT_TEMP_RAW" ] && BAT_TEMP=$(awk "BEGIN { printf \"%.1f\", $BAT_TEMP_RAW/10 }") || BAT_TEMP="N/A"

# -------- Charging Indicator --------
BAT_STATUS_ICON=""
case "$BAT_STATUS" in
  "Charging") BAT_STATUS_ICON="⚡" ;;
  "Full")     BAT_STATUS_ICON="✔️" ;;
esac

# -------- Memory --------
MEM_USED=$(free -m | awk '/Mem:/ { printf "%.2f", $3/1024 }')
MEM_TOTAL=$(free -m | awk '/Mem:/ { printf "%.2f", $2/1024 }')

# -------- Uptime --------
UPTIME=$(awk '{ 
    days=int($1/86400);
    hours=int(($1%86400)/3600);
    mins=int(($1%3600)/60);
    printf "%dd %dh %dm", days, hours, mins
}' /proc/uptime)

# -------- Message --------
MSG='```
⚙️ Load (1m)  —  '"$CPU_LOAD   $LOAD_EMOJI"'
🌡️ Temp       —  '"${CPU_TEMP}°C"'
🔋 Battery    —  '"${BAT}% | ${BAT_TEMP}°C  ${BAT_STATUS_ICON}"'
💾 RAM        —  '"${MEM_USED}GB / ${MEM_TOTAL}GB"'
🕒 Uptime     —  '"$UPTIME"'
```'

# -------- Send --------
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
  -d chat_id="$CHAT_ID" \
  -d text="$MSG" \
  -d parse_mode="Markdown" \
  >/dev/null 2>&1
