#!/bin/sh
# Prints one "kind|id|name|extra|active" line per item for the control center submenus.
case "$1" in
wifi)
    nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null | awk -F: '
        { n=NF; use=$1; sig=$(n-1); sec=$n; ssid=$2; for(i=3;i<=n-2;i++) ssid=ssid ":" $i
          gsub(/\\/,"",ssid); if (ssid=="" || seen[ssid]++) next
          print "wifi|" ssid "|" ssid "|" sig "|" (use=="*" ? 1 : 0) "|" (sec=="" ? 0 : 1) }' | sort -t'|' -k5,5nr -k4,4nr | head -12 ;;
bluetooth)
    bluetoothctl devices Paired 2>/dev/null | while read -r _ mac name; do
        c=0; bluetoothctl info "$mac" 2>/dev/null | grep -q 'Connected: yes' && c=1
        echo "bluetooth|$mac|$name|0|$c|0"
    done | sort -t'|' -k5,5nr ;;
esac
