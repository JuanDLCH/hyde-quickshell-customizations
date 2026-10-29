#!/bin/sh
# One sample of system state, one "key value..." line each.
echo "cpu $(head -1 /proc/stat | cut -d' ' -f2-)"
awk '/^(MemTotal|MemAvailable|SwapTotal|SwapFree):/{gsub(":","",$1); print "mem", $1, $2}' /proc/meminfo
echo "disk $(df -B1 --output=used,size / | tail -1)"
for h in /sys/class/hwmon/hwmon*; do
    if [ "$(cat "$h/name" 2>/dev/null)" = k10temp ]; then echo "temp $(cat "$h/temp1_input")"; break; fi
done
for b in /sys/class/power_supply/BAT*; do
    [ -r "$b/capacity" ] && echo "bat $(cat "$b/capacity") $(cat "$b/status")" && break
done
echo "up $(cut -d' ' -f1 /proc/uptime)"
echo "load $(cut -d' ' -f1 /proc/loadavg)"
