#!/usr/bin/env bash
# i3 autostart — applies monitor layout, starts bar / tray apps / overlay.

# Set monitor positions (defensive — usually KMS already has them right)
xrandr --output DP-1 --primary --mode 2560x1440 --rate 180 --pos 1920x0 \
       --output DP-3 --mode 1920x1080 --rate 60 --pos 0x0 \
       --output DP-2 --mode 1920x1080 --rate 60 --pos 4480x0 \
       --output HDMI-A-1 --mode 1920x1080 --rate 60 --pos 2229x1440 \
       2>/dev/null || true

# Wallpaper
feh --bg-fill /etc/xdg/wallpapers/wall-1.png &

# Compositor (transparency + vsync)
picom --config "$HOME/.config/picom/picom.conf" -b &

# Notifications
pgrep -x dunst >/dev/null || dunst &

# Polybar (one bar per monitor — see polybar/launch.sh)
"$HOME/.config/polybar/launch.sh" &

# Tray apps — launched via wait-tray-then-exec to avoid SNI race
wait-tray-then-exec nm-applet --indicator &
wait-tray-then-exec blueman-applet &
wait-tray-then-exec pasystray &
wait-tray-then-exec vesktop --start-minimized &
wait-tray-then-exec keepassxc &
wait-tray-then-exec qbittorrent &

# Polkit agent
/run/current-system/sw/libexec/polkit-kde-authentication-agent-1 &

# Idle / lock
xss-lock --transfer-sleep-lock -- i3lock --nofork -c 2e3440 &

# Keybind overlay
python3 "$HOME/.config/i3/binds-overlay.py" &
