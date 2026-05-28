#!/usr/bin/env bash
# swap.sh — switch desktop environments
#
# Usage:
#   sudo ./scripts/swap.sh <target>
#
# Targets:
#   kde xfce hypr i3 gnome cinnamon cosmic lxqt sway kde-hypr cli
#
# Handles the KDE plasma-applet-rc snapshot dance so panel layout doesn't get
# clobbered when you swap into KDE.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-kde}"

VALID="kde xfce hypr i3 gnome cinnamon cosmic lxqt sway kde-hypr cli"
if ! grep -qw "$TARGET" <<<"$VALID"; then
    echo "Unknown target: $TARGET"
    echo "Valid: $VALID"
    exit 1
fi

# Need root for nixos-rebuild
if [ "$EUID" -ne 0 ]; then
    echo "Re-run with sudo."; exit 1
fi

CONFIG_HOME="${SUDO_USER:+/home/${SUDO_USER}}"
CONFIG_HOME="${CONFIG_HOME:-$HOME}"
PLASMA_LIVE="$CONFIG_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
PLASMA_SNAP="$CONFIG_HOME/.config/plasma-backups/plasma-appletsrc.stable"

mkdir -p "$(dirname "$PLASMA_SNAP")"

# Pre-swap: if Plasma is running, capture current panel layout so we can
# restore it after a round-trip through a non-KDE DE.
if pgrep -x plasmashell >/dev/null 2>&1; then
    echo "→ Backing up KDE panel state..."
    cp -f "$PLASMA_LIVE" "$PLASMA_SNAP" 2>/dev/null || true
fi

echo "→ Rebuilding system: nixos-rebuild switch --flake $REPO#$TARGET"
nixos-rebuild switch --flake "$REPO#$TARGET"

# Post-swap: if we landed in a KDE-flavoured session AND we have a snapshot,
# restore the layout so tray slots / widgets stay where you put them.
if [[ "$TARGET" =~ ^(kde|kde-hypr)$ ]]; then
    if [ -f "$PLASMA_SNAP" ]; then
        echo "→ Restoring KDE panel state..."
        # Stop plasmashell so it doesn't overwrite the restore mid-flight.
        sudo -u "${SUDO_USER:-$USER}" kquitapp6 plasmashell 2>/dev/null \
            || sudo -u "${SUDO_USER:-$USER}" killall plasmashell 2>/dev/null \
            || true
        sudo -u "${SUDO_USER:-$USER}" kbuildsycoca6 --noincremental 2>/dev/null || true
        cp -f "$PLASMA_SNAP" "$PLASMA_LIVE"
        chown "${SUDO_USER:-$USER}":users "$PLASMA_LIVE" 2>/dev/null || true
        sudo -u "${SUDO_USER:-$USER}" setsid plasmashell >/dev/null 2>&1 &
        echo "→ Restored."
    fi
fi

echo "Done. Active target: $TARGET"
