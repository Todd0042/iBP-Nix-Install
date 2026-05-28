#!/usr/bin/env bash
# seed-from-cachyos.sh — copy logged-in app state out of the mounted
# CachyOS partition (~/CachyOS/home/todd/) and into ~/.persist/.
# persist.nix's activation script then wires each persist entry into the
# matching ~/.config path via symlink on the next nixos-rebuild.
#
# Why this exists: when reinstalling from CachyOS to NixOS on the second
# NVMe, the CachyOS rootfs stays accessible (mounted read-only at
# ~/CachyOS). That makes the snapshot/tarball dance unnecessary — we just
# read the live source and rsync it into ~/.persist on the new disk.
#
# Idempotent. Re-running just refreshes anything that changed.
set -euo pipefail

SRC="${1:-$HOME/CachyOS/home/todd}"
DST="$HOME/.persist"

[ -d "$SRC" ] || {
    echo "ERROR: $SRC not found."
    echo "Is the CachyOS partition mounted? Check with:  ls $HOME/CachyOS"
    echo "If empty, the auto-mount fired but found nothing — check mounts.nix"
    exit 1
}

mkdir -p "$DST"

# Map source-relative path → persist subdir name. Must match the
# `mappings` attrset in persist.nix.
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

# Drop browser/Electron caches — they regenerate, take gigs, slow rsync.
EXCLUDE_OPTS=(
    --exclude='cache2'
    --exclude='Cache'
    --exclude='Cache_Data'
    --exclude='Code Cache'
    --exclude='GPUCache'
    --exclude='ShaderCache'
    --exclude='Crash Reports'
    --exclude='Service Worker/CacheStorage'
    --exclude='startupCache'
    --exclude='thumbnails'
)

echo "Seeding ~/.persist/ from $SRC ..."
echo ""

for rel in "${!MAP[@]}"; do
    dst_name="${MAP[$rel]}"
    src_path="$SRC/$rel"
    dst_path="$DST/$dst_name"

    if [ ! -d "$src_path" ]; then
        printf "  skip   %-30s  (not present)\n" "$rel"
        continue
    fi

    printf "  copy   %-30s  →  ~/.persist/%s\n" "$rel" "$dst_name"
    mkdir -p "$dst_path"
    rsync -a --info=progress2 "${EXCLUDE_OPTS[@]}" \
          "$src_path/" "$dst_path/" 2>/dev/null || \
    rsync -a "${EXCLUDE_OPTS[@]}" "$src_path/" "$dst_path/"
done

# Repos in ~/Documents/GitHub — bring them across with --ignore-existing
# so we don't clobber anything you've already touched on the new system.
if [ -d "$SRC/Documents/GitHub" ]; then
    echo ""
    echo "  copy   Documents/GitHub  →  ~/Documents/GitHub  (--ignore-existing)"
    mkdir -p "$HOME/Documents/GitHub"
    rsync -a --ignore-existing \
          --exclude='.git/objects/pack/*.pack' \
          --exclude='build' --exclude='target' --exclude='node_modules' \
          "$SRC/Documents/GitHub/" "$HOME/Documents/GitHub/"
fi

# Shell histories worth saving
for h in ".local/share/fish/fish_history" \
         ".bash_history" ".zsh_history"; do
    if [ -f "$SRC/$h" ] && [ ! -f "$HOME/$h" ]; then
        mkdir -p "$HOME/$(dirname "$h")"
        cp "$SRC/$h" "$HOME/$h"
        echo "  copy   $h"
    fi
done

# Permission fix in case rsync ran as root somewhere
chown -R "$USER":users "$DST" 2>/dev/null || \
    sudo chown -R "$USER":users "$DST" 2>/dev/null || true

echo ""
echo "Done. Now run:"
echo "  sudo $HOME/Documents/GitHub/iBP-Nix-Install/scripts/swap.sh kde"
echo "Then log out → back in. Apps should already be logged in."
