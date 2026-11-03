#!/usr/bin/env bash
# Only runs on panel visibility changes or explicit clicks; no polling daemon.
set -euo pipefail
case ${1:-} in
    wifi-state)
        if [[ $(LC_ALL=C nmcli radio wifi 2>/dev/null) == enabled ]]; then echo true; else echo false; fi ;;
    bluetooth-state)
        if LC_ALL=C bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then echo true; else echo false; fi ;;
    wifi-set)
        case ${SWAYNC_TOGGLE_STATE:-} in true) state=on;; false) state=off;; *) exit 2;; esac
        nmcli radio wifi "$state" || notify-send -a HyDE 'Wi-Fi' 'No se pudo cambiar el estado de Wi-Fi.' ;;
    bluetooth-set)
        case ${SWAYNC_TOGGLE_STATE:-} in true) state=on;; false) state=off;; *) exit 2;; esac
        bluetoothctl power "$state" || notify-send -a HyDE 'Bluetooth' 'No se pudo cambiar el estado de Bluetooth.' ;;
    dnd-state) swaync-client --get-dnd --skip-wait ;;
    dnd-set)
        case ${SWAYNC_TOGGLE_STATE:-} in
            true) swaync-client --dnd-on --skip-wait ;;
            false) swaync-client --dnd-off --skip-wait ;;
            *) exit 2 ;;
        esac ;;
    awake-state)
        hyde-shell caffeine -rq | python3 -c 'import json,sys; print("true" if json.load(sys.stdin).get("alt")=="activated" else "false")' ;;
    awake-set)
        case ${SWAYNC_TOGGLE_STATE:-} in true|false) ;; *) exit 2;; esac
        current=$("$0" awake-state)
        if [[ $current != "$SWAYNC_TOGGLE_STATE" ]]; then
            hyde-shell caffeine -tq -P waybar,21
        fi ;;
    *) printf 'Usage: control-center.sh {wifi,bluetooth,dnd,awake}-{state,set}\n' >&2; exit 2 ;;
esac
