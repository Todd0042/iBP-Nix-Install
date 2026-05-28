#!/usr/bin/env bash
# snapshot-home.sh — bundle your logged-in app state into a tarball you can
# carry across installs.
#
# What this captures (only what fits the "keep me logged in" goal):
#   ~/.mozilla/firefox/             Firefox profiles (login, addons, history)
#   ~/.config/vesktop/              Vesktop (Discord) auth tokens
#   ~/.config/discord/              Discord proper
#   ~/.config/BraveSoftware/        Brave sessions
#   ~/.config/vivaldi/              Vivaldi
#   ~/.librewolf/                   LibreWolf
#   ~/.config/keepassxc/            KeePassXC settings
#   ~/.config/obsidian/             Obsidian vault list + settings
#   ~/.config/Code/                 VS Code (Microsoft) extensions/login
#   ~/.vscode/                      VS Code extension state
#   ~/.claude/                      Claude Code memory + history
#   ~/.config/GitHub Desktop/       GitHub Desktop session
#   ~/.config/qBittorrent/          qBittorrent settings
#   ~/.config/sunshine/             Sunshine streaming config
#   ~/.config/obs-studio/           OBS scenes/profiles
#   ~/.thunderbird/                 Thunderbird (if present)
#   ~/Documents/GitHub/             your repos
#
# What it deliberately SKIPS:
#   - Firefox cache (CACHE/* under each profile)
#   - VS Code extensions cache (CachedExtensions/)
#   - Steam game downloads (use Steam's own library transfer)
#   - Browser session media (HTTP cache)
#
# Usage:
#   ./scripts/snapshot-home.sh              → ~/home-snapshot-YYYY-MM-DD.tar.zst
#   ./scripts/snapshot-home.sh /backup/dir  → write into a chosen dir
set -euo pipefail

OUT_DIR="${1:-$HOME}"
STAMP=$(date +%F-%H%M%S)
OUT="$OUT_DIR/home-snapshot-${STAMP}.tar.zst"

if ! command -v zstd >/dev/null; then
    echo "Need zstd. Install: nix-shell -p zstd"
    exit 1
fi

# Run as the real user — tar will preserve perms relative to $HOME.
cd "$HOME"

# Use a temp file for the include list so spaces in paths survive.
INCLUDE=$(mktemp)
cat >"$INCLUDE" <<'EOF'
.mozilla/firefox
.config/vesktop
.config/discord
.config/discord-canary
.config/BraveSoftware
.config/vivaldi
.librewolf
.config/keepassxc
.config/obsidian
.config/Code
.vscode
.claude
.config/GitHub Desktop
.config/qBittorrent
.config/sunshine
.config/obs-studio
.thunderbird
.config/fish
Documents/GitHub
EOF

EXCLUDE=(
    --exclude='*/cache2'
    --exclude='*/Cache'
    --exclude='*/Cache_Data'
    --exclude='*/Code Cache'
    --exclude='*/GPUCache'
    --exclude='*/Crash Reports'
    --exclude='*/Service Worker/CacheStorage'
    --exclude='.mozilla/firefox/*/storage/default/*/cache'
    --exclude='node_modules'
    --exclude='target/release'
    --exclude='target/debug'
    --exclude='build'
    --exclude='.next'
    --exclude='.cache'
)

# Build the tar one input-line per file so spaces survive ("GitHub Desktop").
echo "→ Snapshotting to $OUT ..."
# shellcheck disable=SC2002
tar --files-from="$INCLUDE" -cf - --ignore-failed-read \
    "${EXCLUDE[@]}" 2>/dev/null \
  | zstd -T0 -19 --long -o "$OUT" -

SIZE=$(du -h "$OUT" | cut -f1)
rm -f "$INCLUDE"
echo "→ Done: $OUT ($SIZE)"
echo ""
echo "Restore on a fresh install with:"
echo "  ./scripts/restore-home.sh $OUT"
