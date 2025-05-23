#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RESET='\033[0m'
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

separator="================================================================================"

print_header() {
    echo -e "\n${CYAN}${BOLD}$1${RESET}"
    echo "$separator"
}

# ------------------------ OS Info ------------------------

print_header "OS Info"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "${GREEN}${NAME} ${VERSION}${RESET}"
else
    uname -a
fi

# ------------------------ CPU Uptime ------------------------

read system_uptime idle_time < /proc/uptime

total_seconds=${system_uptime%.*}
fractional_part=${system_uptime#*.}

days=$((total_seconds / 86400 ))
hours=$(((total_seconds % 86400) / 3600 ))
minutes=$(((total_seconds % 3600) / 60 ))
seconds=$((total_seconds % 60 ))

print_header "CPU Uptime"

# Print only non-zero units
[[ $days -gt 0 ]] && echo "$days days"
[[ $hours -gt 0 ]] && echo "$hours hours"
[[ $minutes -gt 0 ]] && echo "$minutes minutes"
[[ $seconds -gt 0 || $fractional_part -ne 0 ]] && echo "$seconds.${fractional_part} seconds"


# ------------------------ CPU Usage ------------------------

top_output=$(top -bn1)

cpu_idle=$(echo "$top_output" | grep "Cpu(s)" | sed 's/.*, *\([0-9.]*\)%* id.*/\1/')
cpu_usage=$(awk -v idle="$cpu_idle" 'BEGIN { printf("%.1f", 100 - idle) }')

print_header "🖥️  CPU Usage"
echo -e "Usage         : ${GREEN}${cpu_usage}%${RESET}"


# ------------------------ Memory Usage ------------------------

read total_memory available_memory <<< $(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {print t, a}' /proc/meminfo)
used_memory=$((total_memory - available_memory))

used_memory_percent=$(awk -v u=$used_memory -v t=$total_memory 'BEGIN { printf("%.1f", (u / t) * 100) }')
free_memory_percent=$(awk -v a=$available_memory -v t=$total_memory 'BEGIN { printf("%.1f", (a / t) * 100) }')

# Convert from kB to MB 
total_memory_mb=$(awk -v t=$total_memory 'BEGIN { printf("%.1f", t/1024) }')
used_memory_mb=$(awk -v u=$used_memory 'BEGIN { printf("%.1f", u/1024) }')
available_memory_mb=$(awk -v a=$available_memory 'BEGIN { printf("%.1f", a/1024) }')

print_header "🧠 Memory Usage"
printf "Total Memory    : ${YELLOW}%-10s MB${RESET}\n" "$total_memory_mb"
printf "Used Memory     : ${YELLOW}%-10s MB${RESET} (%s%%)\n" "$used_memory_mb" "$used_memory_percent"
printf "Free/Available  : ${YELLOW}%-10s MB${RESET} (%s%%)\n" "$available_memory_mb" "$free_memory_percent"


# ------------------------ Disk Usage ------------------------

df_output=$(df -h /)
size_disk=$(echo "$df_output" | awk 'NR==2 {printf $2}')
# Dont use printf in below line, it doesnt add space
read used_disk available_disk <<< $(echo "$df_output" | awk 'NR==2 {print $3, $4}')

df_output_raw=$(df /)
read size_disk_kb used_disk_kb available_disk_kb <<< $(echo "$df_output_raw" | awk 'NR==2 {print $2, $3, $4}')

if command -v bc &> /dev/null; then
  used_disk_percent=$(echo "scale=2; $used_disk_kb * 100 / $size_disk_kb" | bc)
  available_disk_percent=$(echo "scale=2; $available_disk_kb * 100 / $size_disk_kb" | bc)
else
  used_disk_percent=$(( used_disk_kb * 100 / size_disk_kb ))
  available_disk_percent=$((available_disk_kb * 100 / size_disk_kb))
fi



print_header "💾 Disk Usage"
printf "Disk Size       : ${YELLOW}%-10s${RESET}\n" "$size_disk"
printf "Used Space      : ${YELLOW}%-10s${RESET} (%s%%)\n" "$used_disk" "$used_disk_percent"
printf "Available Space : ${YELLOW}%-10s${RESET} (%s%%)\n" "$available_disk" "$available_disk_percent"


# ------------------------ Top Processes ------------------------

print_header "🔥 Top 5 Processes by CPU"
ps aux --sort=-%cpu | awk 'NR==1 || NR<=6 { printf "%-10s %-6s %-5s %-5s %s\n", $1, $2, $3, $4, $11 }'

print_header "🧠 Top 5 Processes by Memory"
ps aux --sort=-%mem | awk 'NR==1 || NR<=6 { printf "%-10s %-6s %-5s %-5s %s\n", $1, $2, $3, $4, $11 }'

# ----------------------- Temperature Monitoring ------------------

print_header "🌡️ Temperature"
for temp_file in /sys/class/thermal/thermal_zone*/temp; do
    if [ -f "$temp_file" ]; then
        temp=$(cat "$temp_file")
        echo -e "CPU Max Temp: ${YELLOW}$((temp/1000))°C${RESET}"
        break  # Only read from the first matching file
    fi
done

# ---------------------- Network Monitoring -----------------------

# print_header "🌐 Network Stats"
# if command -v ss &> /dev/null; then
#     echo -e "${YELLOW}Active Connections:${RESET}"
#     ss -s | head -4
# else
#     netstat -i
# fi

print_header "🌐 IP Addresses"

# Get private IPs (modern systems)
if command -v ip &> /dev/null; then
    ip -br addr show | awk '$1 !~ "lo" && $3 ~ /^[0-9]/ {print $1 ": " $3}'
# Fallback for older systems
elif command -v ifconfig &> /dev/null; then
    ifconfig | awk '/inet / && !/127.0.0.1/ {print $2}' | xargs -I {} echo "eth0: {}"
else
    echo "No IP tools available"
fi

# Get public IP (if internet available)
echo -e "\n${YELLOW}Public IP:${RESET}"
(curl -s ifconfig.me || wget -qO- ifconfig.me) 2>/dev/null || echo "Not available"
echo