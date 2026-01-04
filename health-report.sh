#!/bin/sh

# -------- Telegram Config --------
CONFIG_FILE="/home/neo/.config/telebot/bot.conf"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Telegram config not found: $CONFIG_FILE" >&2
  exit 1
fi
. "$CONFIG_FILE"


# -------- Uptime --------
UPTIME=$(awk '{ 
    days=int($1/86400);
    hours=int(($1%86400)/3600);
    mins=int(($1%3600)/60);
    printf "%dd %dh %dm", days, hours, mins
}' /proc/uptime)

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

# -------- Network (Wi-Fi only) --------
SSID=$(nmcli -t -f ACTIVE,SSID dev wifi | awk -F: '$1=="yes" {print $2; exit}')
WIFI_IF=$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi" {print $1; exit}')
WIFI_IP=$(ip -4 addr show "$WIFI_IF" 2>/dev/null | awk '/inet / {print $2; exit}' | cut -d/ -f1)

if [ -n "$SSID" ] && [ -n "$WIFI_IF" ] && [ -n "$WIFI_IP" ]; then
  NET_NAME="$SSID"
  NET_IFACE="$WIFI_IF"
  NET_IP="$WIFI_IP"
else
  NET_NAME="offline"
  NET_IFACE="-"
  NET_IP="-"
fi

# -------- Memory --------
read MEM_TOTAL MEM_USED <<EOF
$(free -m | awk '/Mem:/ { print $2, $3 }')
EOF
RAM_PCT=$(( MEM_USED * 100 / MEM_TOTAL ))

# -------- Disk (Root) --------
ROOT_USED=$(df -hP / | awk 'NR==2 {print $3}')
ROOT_TOTAL=$(df -hP / | awk 'NR==2 {print $2}')
ROOT_PCT=$(df -hP / | awk 'NR==2 {print $5}')

# -------- Disk (SD Card) --------
if mountpoint -q /mnt/sdcard; then
  SD_USED=$(df -hP /mnt/sdcard | awk 'NR==2 {print $3}')
  SD_TOTAL=$(df -hP /mnt/sdcard | awk 'NR==2 {print $2}')
  SD_PCT=$(df -hP /mnt/sdcard | awk 'NR==2 {print $5}')
  SD_STATUS="${SD_USED} / ${SD_TOTAL} (${SD_PCT})"
else
  SD_STATUS="not mounted"
fi

# -------- Message --------
MSG='```
🕒 Uptime          —  '"${UPTIME}"'
⚙️ Load            —  '"${CPU_LOAD}"'
🌡️ CPU Temp        —  '"${CPU_TEMP}°C"'
🌡️ SOC Temp        —  '"${SOC_TEMP}°C"'

🔋 Battery         —  '"${BAT}% | ${BAT_TEMP}°C"'
🔋 Battery Status  —  '"${BAT_STATUS}"'

🌐 Network         —  '"${NET_NAME}"'
🌐 Interface       —  '"${NET_IFACE}"'
🌐 IP              —  '"${NET_IP}"'

💾 RAM             —  '"${MEM_USED}MB / ${MEM_TOTAL}MB (${RAM_PCT}%)"'
💽 Root Disk       —  '"${ROOT_USED} / ${ROOT_TOTAL} (${ROOT_PCT})"'
💽 SD Card         —  '"${SD_STATUS}"'
```'

# -------- Send --------
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
  -d chat_id="$CHAT_ID" \
  -d text="$MSG" \
  -d parse_mode="Markdown" \
  >/dev/null 2>&1
