#!/usr/bin/env bash
# City-level weather for the lock screen. Never emit untrusted provider text into Pango markup.
# Location: $HYDE_QS_WEATHER_LOCATION or the first line of ~/.config/hyde/weather-location
# (e.g. "Madrid,Spain"). With no location configured the script prints nothing.
loc=${HYDE_QS_WEATHER_LOCATION:-$(head -n1 "${XDG_CONFIG_HOME:-$HOME/.config}/hyde/weather-location" 2>/dev/null)}
[[ -n $loc && $loc =~ ^[A-Za-z0-9,\ _.-]+$ ]] || exit 0
value=$(curl --fail --silent --connect-timeout 3 --max-time 8 --max-filesize 128 "https://wttr.in/${loc// /+}?format=%f&m" 2>/dev/null) || exit 0
if [[ $value =~ ^[+-]?[0-9]+([.][0-9]+)?°C$ ]]; then
    printf '<b>Feels like<big> %s </big></b>\n' "${value#+}"
fi
