#!/usr/bin/env bash
# bootstrap.sh — interactive (or --auto) NixOS install wizard tuned for
# Todd's dual-NVMe layout. Run from inside the booted ISO.
#
# Goals:
#   - Default to wiping nvme1n1 (PNY CS2241) and putting NixOS there.
#   - LEAVE nvme0n1 alone (Windows + CachyOS dual-boot).
#   - After install, you can boot NixOS via the UEFI boot menu or chainload
#     from CachyOS' grub-mkconfig (os-prober finds it).
#
# Usage:
#   sudo /etc/iBP-Nix-Install/bootstrap.sh             # interactive
#   sudo /etc/iBP-Nix-Install/bootstrap.sh --auto kde  # one-shot, KDE
set -euo pipefail

REPO_GIT="https://github.com/Todd0042/iBP-Nix-Install.git"
WORKDIR="/tmp/iBP-Nix-Install"

# -----------------------------------------------------------
# ARG PARSE
# -----------------------------------------------------------
AUTO=0
TARGET_DE=""
TARGET_DISK=""
RESTORE_SNAP=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto)     AUTO=1 ;;
        --help|-h)
            cat <<EOF
Usage: $0 [--auto] [<de>] [--disk /dev/nvmeXn1] [--restore /path/to/snapshot.tar.zst]

Targets (de):  kde xfce hypr i3 kde-hypr gnome cinnamon cosmic lxqt sway cli
Default:       kde
Default disk:  /dev/nvme1n1  (the PNY drive — assumed dedicated)
EOF
            exit 0 ;;
        --disk)     TARGET_DISK="$2"; shift ;;
        --restore)  RESTORE_SNAP="$2"; shift ;;
        kde|xfce|hypr|i3|kde-hypr|gnome|cinnamon|cosmic|lxqt|sway|cli)
            TARGET_DE="$1" ;;
        *)
            echo "Unknown argument: $1"
            exit 1 ;;
    esac
    shift
done

[ "$EUID" -eq 0 ] || { echo "Run as root."; exit 1; }

echo "==============================================="
echo "  iBP-Nix-Install bootstrap"
echo "==============================================="

# -----------------------------------------------------------
# BOOT MODE
# -----------------------------------------------------------
if [ -d /sys/firmware/efi ]; then
    BOOT_MODE="uefi"
else
    echo "ERROR: BIOS boot not supported by this installer." ; exit 1
fi
echo "  Boot mode: $BOOT_MODE"

# -----------------------------------------------------------
# DISK SELECTION
# -----------------------------------------------------------
echo ""
echo "Available block devices:"
lsblk -d -o NAME,MODEL,SIZE,SERIAL,TYPE | grep disk

if [ -z "$TARGET_DISK" ]; then
    # Prefer nvme1n1 if it exists — that's the PNY in Todd's layout.
    if [ -b /dev/nvme1n1 ]; then
        TARGET_DISK="/dev/nvme1n1"
        echo ""
        echo "Default target: $TARGET_DISK (PNY — second NVMe)"
    else
        TARGET_DISK="/dev/nvme0n1"
        echo ""
        echo "Default target: $TARGET_DISK (only NVMe detected)"
    fi

    if [ "$AUTO" -eq 0 ]; then
        read -r -p "Install target [default $TARGET_DISK]: " ans
        [ -n "$ans" ] && TARGET_DISK="$ans"
    fi
fi

[[ "$TARGET_DISK" == /dev/* ]] || TARGET_DISK="/dev/$TARGET_DISK"
[ -b "$TARGET_DISK" ] || { echo "Not a block device: $TARGET_DISK"; exit 1; }

# -----------------------------------------------------------
# DE SELECTION
# -----------------------------------------------------------
if [ -z "$TARGET_DE" ]; then
    if [ "$AUTO" -eq 1 ]; then
        TARGET_DE="kde"
    else
        echo ""
        echo "Pick a desktop environment:"
        select OPT in kde xfce hypr i3 kde-hypr gnome cinnamon cosmic lxqt sway cli; do
            [ -n "$OPT" ] && TARGET_DE="$OPT" && break
        done
    fi
fi

# -----------------------------------------------------------
# GPU DETECT (for documentation; gpu.nix is layered manually)
# -----------------------------------------------------------
GPU_RAW=$(lspci | grep -Ei "VGA|3D|Display" || true)
echo ""
echo "GPU(s):"
echo "$GPU_RAW" | sed 's/^/  /'

if echo "$GPU_RAW" | grep -qi nvidia; then
    GPU_PROFILE="nvidia"
elif echo "$GPU_RAW" | grep -qi amd; then
    GPU_PROFILE="amd"
else
    GPU_PROFILE="intel"
fi
echo "  Detected profile: $GPU_PROFILE"

# -----------------------------------------------------------
# FINAL CONFIRM
# -----------------------------------------------------------
echo ""
echo "Summary:"
echo "  target disk  : $TARGET_DISK   (will be WIPED)"
echo "  desktop env  : $TARGET_DE"
echo "  GPU profile  : $GPU_PROFILE"
[ -n "$RESTORE_SNAP" ] && echo "  restore snap : $RESTORE_SNAP"
echo ""

if [ "$AUTO" -eq 0 ]; then
    read -r -p "Proceed? (yes/NO): " ans
    [[ "$ans" =~ ^[Yy][Ee][Ss]$ ]] || { echo "Aborted."; exit 1; }
fi

# -----------------------------------------------------------
# FETCH REPO
# -----------------------------------------------------------
if [ ! -d "$WORKDIR/.git" ]; then
    echo "Cloning $REPO_GIT → $WORKDIR"
    git clone "$REPO_GIT" "$WORKDIR"
fi
cd "$WORKDIR"

export TARGET_DISK TARGET_DE GPU_PROFILE RESTORE_SNAP
bash "$WORKDIR/scripts/install-core.sh"
