#!/usr/bin/env bash
# post-install.sh — run on first boot if you skipped --restore at install
# time. Sets up the new password, restores a home snapshot if given.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== POST-INSTALL ==="

# -----------------------------
# CHANGE DEFAULT PASSWORD
# -----------------------------
echo "→ Set a new password for todd:"
passwd todd

# -----------------------------
# OPTIONAL HOME SNAPSHOT RESTORE
# -----------------------------
read -r -p "Path to a home snapshot tarball (blank to skip): " SNAP
if [ -n "$SNAP" ] && [ -f "$SNAP" ]; then
    sudo -u todd "$REPO/scripts/restore-home.sh" "$SNAP"
    echo "→ Restored. Run: sudo $REPO/scripts/swap.sh kde     to wire links."
fi

echo "Done. Reboot or log out → in to pick up KDE / persist symlinks."
