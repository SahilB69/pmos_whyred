#!/bin/sh

# -------- Telegram Config --------
CONFIG_FILE="/home/neo/.config/telebot/bot.conf"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Telegram config not found: $CONFIG_FILE" >&2
  exit 1
fi
. "$CONFIG_FILE"

# -------- CPU Average Load --------
read LOAD_1 LOAD_5 LOAD_15 _ < /proc/loadavg
CPU_LOAD="$LOAD_1 | $LOAD_5 | $LOAD_15"

# -------- CPU Temperature --------
CPU0_RAW=$(cat /sys/class/thermal/thermal_zone1/temp)
CPU1_RAW=$(cat /sys/class/thermal/thermal_zone2/temp)
CPU_MAX_RAW=$(( CPU0_RAW > CPU1_RAW ? CPU0_RAW : CPU1_RAW ))
CPU_TEMP=$(awk "BEGIN { printf \"%.1f\", $CPU_MAX_RAW/1000 }")

# -------- SOC Temperature --------
SOC_TEMP_RAW=$(cat /sys/class/thermal/thermal_zone0/temp)
SOC_TEMP=$(awk "BEGIN { printf \"%.1f\", $SOC_TEMP_RAW/1000 }")

# -------- Battery --------
BAT=$(cat /sys/class/power_supply/qcom-battery/capacity 2>/dev/null || echo "N/A")
BAT_STATUS=$(cat /sys/class/power_supply/qcom-battery/status 2>/dev/null || echo "Unknown")

# -------- Battery Temperature --------
BAT_TEMP_RAW=$(cat /sys/class/power_supply/qcom-battery/temp)
BAT_TEMP=$(awk "BEGIN { printf \"%.1f\", $BAT_TEMP_RAW/10 }")

# -------- Memory --------
read MEM_TOTAL MEM_USED <<EOF
$(free -m | awk '/Mem:/ { print $2, $3 }')
EOF

# -------- Uptime --------
UPTIME=$(awk '{ 
    days=int($1/86400);
    hours=int(($1%86400)/3600);
    mins=int(($1%3600)/60);
    printf "%dd %dh %dm", days, hours, mins
}' /proc/uptime)

# -------- Message --------
MSG='```
⚙️ Load            —  '"${CPU_LOAD}"'
🌡️ CPU Temp        —  '"${CPU_TEMP}°C"'
🌡️ SOC Temp        —  '"${SOC_TEMP}°C"'

🔋 Battery         —  '"${BAT}% | ${BAT_TEMP}°C"'
🔋 Battery Status  —  '"${BAT_STATUS}"'

💾 RAM             —  '"${MEM_USED}MB / ${MEM_TOTAL}MB"'
🕒 Uptime          —  '"${UPTIME}"'
```'

# -------- Send --------
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
  -d chat_id="$CHAT_ID" \
  -d text="$MSG" \
  -d parse_mode="Markdown" \
  >/dev/null 2>&1
