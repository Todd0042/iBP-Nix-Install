#!/usr/bin/env bash
# restore-home.sh — replant a snapshot from snapshot-home.sh into ~/.persist
# and (optionally) verify the activation script linked everything up.
#
# Usage:   ./scripts/restore-home.sh <snapshot.tar.zst>
set -euo pipefail

SNAP="${1:?path to snapshot tarball required}"
[ -f "$SNAP" ] || { echo "Not a file: $SNAP"; exit 1; }

PERSIST="$HOME/.persist"
mkdir -p "$PERSIST"

echo "→ Extracting into a staging dir..."
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

zstd -d -c "$SNAP" | tar -x -C "$STAGE"

echo "→ Moving each app's state under ~/.persist/ ..."
# Map snapshot path → persist subdir name (must match persist.nix `mappings`)
declare -A MAP=(
  [".mozilla/firefox"]=firefox
  [".config/vesktop"]=vesktop
  [".config/discord"]=discord
  [".config/discord-canary"]=discord
  [".config/BraveSoftware"]=brave
  [".config/vivaldi"]=vivaldi
  [".librewolf"]=librewolf
  [".config/keepassxc"]=keepassxc
  [".config/obsidian"]=obsidian
  [".config/Code"]=vscode
  [".vscode"]=vscode-fhs
  [".claude"]=claude
  [".config/GitHub Desktop"]=github-desktop
  [".config/qBittorrent"]=qbittorrent
  [".config/sunshine"]=sunshine-cfg
  [".config/obs-studio"]=obs-studio
  [".thunderbird"]=thunderbird
)

for src in "${!MAP[@]}"; do
    dst="${MAP[$src]}"
    if [ -d "$STAGE/$src" ]; then
        echo "   → $src  →  ~/.persist/$dst"
        rm -rf "$PERSIST/$dst"
        mkdir -p "$(dirname "$PERSIST/$dst")"
        mv "$STAGE/$src" "$PERSIST/$dst"
    fi
done

# Also restore your Documents/GitHub repos verbatim (NOT through ~/.persist).
if [ -d "$STAGE/Documents/GitHub" ]; then
    echo "   → Documents/GitHub  →  ~/Documents/GitHub"
    mkdir -p "$HOME/Documents"
    rsync -a --info=progress2 "$STAGE/Documents/GitHub/" "$HOME/Documents/GitHub/"
fi

# Fish config restored to its native spot
if [ -d "$STAGE/.config/fish" ]; then
    echo "   → fish history & funcs  →  ~/.config/fish"
    rsync -a "$STAGE/.config/fish/" "$HOME/.config/fish/"
fi

chown -R "$USER":users "$PERSIST" 2>/dev/null || true

echo ""
echo "Done. Next steps:"
echo "  1. sudo ./scripts/swap.sh kde        (re-activate to wire symlinks)"
echo "  2. log out / back in"
echo "  3. open each app — should already be logged in"
