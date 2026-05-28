#!/usr/bin/env bash
# discover-mounts.sh — auto-fill UUIDs in mounts.nix from live blkid.
#
# Usage:   sudo ./scripts/discover-mounts.sh
#
# What it does:
#   1. Scans every block device with `blkid`.
#   2. Picks the largest NTFS partition labelled "Windows" (or asks if there's
#      more than one candidate).
#   3. Picks the largest ext4 partition that ISN'T the current NixOS root,
#      treats that as CachyOS / sibling Linux.
#   4. Rewrites the two UUID lines in mounts.nix in place.
#
# Idempotent: re-running just refreshes the values.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOUNTS="$REPO/mounts.nix"

if [ ! -f "$MOUNTS" ]; then
    echo "ERROR: $MOUNTS not found"; exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "Re-run with sudo (need blkid access to NTFS partitions)."
    exit 1
fi

current_root_uuid=$(findmnt -n -o UUID /)
echo "Current NixOS root UUID (excluded from picks): $current_root_uuid"

# ── Find Windows NTFS partition ───────────────────────────────────
declare -A ntfs_sizes ntfs_uuids
while IFS= read -r line; do
    dev=$(echo "$line" | awk '{print $1}' | tr -d :)
    uuid=$(echo "$line" | grep -oP 'UUID="\K[^"]+' || true)
    label=$(echo "$line" | grep -oP 'LABEL="\K[^"]+' || true)
    [ -z "$uuid" ] && continue
    [ -z "$dev"  ] && continue
    size=$(blockdev --getsize64 "$dev" 2>/dev/null || echo 0)
    ntfs_sizes["$dev"]=$size
    ntfs_uuids["$dev"]=$uuid
    printf "  candidate NTFS: %-22s  %12s  UUID=%s  LABEL=%s\n" \
        "$dev" "$(numfmt --to=iec --suffix=B $size)" "$uuid" "${label:-}"
done < <(blkid -t TYPE=ntfs)

# Pick the largest
win_dev=""; win_size=0; win_uuid=""
for dev in "${!ntfs_sizes[@]}"; do
    if (( ${ntfs_sizes[$dev]} > win_size )); then
        win_size=${ntfs_sizes[$dev]}
        win_dev=$dev
        win_uuid=${ntfs_uuids[$dev]}
    fi
done

# ── Find CachyOS / sibling Linux ext4 ─────────────────────────────
sibling_uuid=""; sibling_dev=""; sibling_size=0
while IFS= read -r line; do
    dev=$(echo "$line" | awk '{print $1}' | tr -d :)
    uuid=$(echo "$line" | grep -oP 'UUID="\K[^"]+' || true)
    [ -z "$uuid" ] && continue
    [ "$uuid" = "$current_root_uuid" ] && continue   # skip our own /
    size=$(blockdev --getsize64 "$dev" 2>/dev/null || echo 0)
    printf "  candidate ext4: %-22s  %12s  UUID=%s\n" \
        "$dev" "$(numfmt --to=iec --suffix=B $size)" "$uuid"
    if (( size > sibling_size )); then
        sibling_size=$size
        sibling_dev=$dev
        sibling_uuid=$uuid
    fi
done < <(blkid -t TYPE=ext4)

echo ""
echo "Resolved:"
echo "  Windows   → ${win_dev:-(none)}    UUID=${win_uuid:-(none)}"
echo "  CachyOS/Linux → ${sibling_dev:-(none)}  UUID=${sibling_uuid:-(none)}"
echo ""

# ── Patch mounts.nix ──────────────────────────────────────────────
if [ -n "$sibling_uuid" ]; then
    sed -i -E "s|^(  cachyOsRootUUID = )\".*\";|\\1\"$sibling_uuid\";|" "$MOUNTS"
    echo "  ✓ patched cachyOsRootUUID"
fi
if [ -n "$win_uuid" ]; then
    sed -i -E "s|^(  windowsNtfsUUID = )\".*\";|\\1\"$win_uuid\";|" "$MOUNTS"
    echo "  ✓ patched windowsNtfsUUID"
else
    echo "  ⚠ no NTFS partition found — Windows mount will stay disabled"
fi

echo ""
echo "Done. Review the diff:"
echo "    git -C $REPO diff -- mounts.nix"
echo "Then rebuild:"
echo "    sudo ./scripts/swap.sh kde       # or whichever DE you're on"
