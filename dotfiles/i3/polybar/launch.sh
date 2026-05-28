#!/usr/bin/env bash
# Launch a polybar per connected monitor.
killall -q polybar
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 0.2; done

CONFIG="$HOME/.config/polybar/config.ini"

connected_outputs() {
    xrandr --query | awk '/ connected/ { print $1 }'
}

for out in $(connected_outputs); do
    case "$out" in
        DP-1)      MONITOR=$out polybar --reload primary -c "$CONFIG" &>/tmp/polybar-$out.log &;;
        DP-3)      MONITOR=$out polybar --reload left    -c "$CONFIG" &>/tmp/polybar-$out.log &;;
        DP-2)      MONITOR=$out polybar --reload right   -c "$CONFIG" &>/tmp/polybar-$out.log &;;
        HDMI-A-1)  MONITOR=$out polybar --reload bottom  -c "$CONFIG" &>/tmp/polybar-$out.log &;;
        *)         MONITOR=$out polybar --reload left    -c "$CONFIG" &>/tmp/polybar-$out.log &;;
    esac
done
