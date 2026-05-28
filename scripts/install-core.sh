#!/usr/bin/env bash
# install-core.sh — partition + format + nixos-install. Called from
# bootstrap.sh with TARGET_DISK / TARGET_DE / GPU_PROFILE / RESTORE_SNAP in env.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

: "${TARGET_DISK:?TARGET_DISK not set}"
: "${TARGET_DE:?TARGET_DE not set}"
: "${GPU_PROFILE:=nvidia}"
RESTORE_SNAP="${RESTORE_SNAP:-}"

echo "=== INSTALL CORE ==="
echo "  disk : $TARGET_DISK"
echo "  de   : $TARGET_DE"
echo "  gpu  : $GPU_PROFILE"

# -----------------------------------------------------------
# PARTITION NAMING
# -----------------------------------------------------------
if [[ "$TARGET_DISK" == *nvme* ]] || [[ "$TARGET_DISK" =~ [0-9]$ ]]; then
    P1="${TARGET_DISK}p1"
    P2="${TARGET_DISK}p2"
else
    P1="${TARGET_DISK}1"
    P2="${TARGET_DISK}2"
fi

# -----------------------------------------------------------
# WIPE + PARTITION (GPT, 2 GiB ESP + ext4 rest)
# -----------------------------------------------------------
echo "→ Wiping signatures on $TARGET_DISK"
wipefs -a "$TARGET_DISK"

echo "→ Writing GPT"
parted "$TARGET_DISK" --script mklabel gpt
parted "$TARGET_DISK" --script mkpart ESP fat32 1MiB 2GiB
parted "$TARGET_DISK" --script set 1 esp on
parted "$TARGET_DISK" --script mkpart primary ext4 2GiB 100%

udevadm settle

# -----------------------------------------------------------
# FORMAT + MOUNT
# -----------------------------------------------------------
mkfs.fat -F32 -n NIXBOOT "$P1"
mkfs.ext4 -L NIXROOT  "$P2"

mount "$P2" /mnt
mkdir -p /mnt/boot
mount "$P1" /mnt/boot

# -----------------------------------------------------------
# HARDWARE CONFIG
# -----------------------------------------------------------
echo "→ Generating /etc/nixos/hardware-configuration.nix"
nixos-generate-config --root /mnt

cp -f /mnt/etc/nixos/hardware-configuration.nix \
      "$REPO/hardware-configuration.nix"

# -----------------------------------------------------------
# SCAFFOLD gpu.nix (NVIDIA single-dGPU desktop, no Intel iGPU)
# -----------------------------------------------------------
if [ ! -f "$REPO/gpu.nix" ]; then
    echo "→ Scaffolding gpu.nix for profile: $GPU_PROFILE"
    case "$GPU_PROFILE" in
        nvidia)
            cat > "$REPO/gpu.nix" <<'EOF'
# gpu.nix — NVIDIA desktop (single dGPU; NO Intel iGPU on i7-14700F)
{ config, pkgs, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    package             = config.boot.kernelPackages.nvidiaPackages.latest;
    modesetting.enable  = true;
    powerManagement.enable      = true;
    powerManagement.finegrained = false;
    open                = true;           # open kernel module (Turing+)
    nvidiaSettings      = true;
  };

  # No `hardware.nvidia.prime` block — there is no iGPU to offload to.
}
EOF
            ;;
        amd)
            cat > "$REPO/gpu.nix" <<'EOF'
{ config, pkgs, ... }:
{
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.amdgpu.opencl.enable = true;
}
EOF
            ;;
        intel)
            cat > "$REPO/gpu.nix" <<'EOF'
{ config, pkgs, ... }:
{
  services.xserver.videoDrivers = [ "modesetting" ];
}
EOF
            ;;
    esac
fi

# -----------------------------------------------------------
# AUTO-FILL mounts.nix WITH UUIDs FROM EXISTING DISKS
# -----------------------------------------------------------
# At install time we can read every disk that isn't $TARGET_DISK.
echo "→ Probing for Windows/CachyOS partitions to mount in ~/"
WIN_UUID=$(blkid -t TYPE=ntfs | while read line; do
    dev=$(echo "$line" | awk '{print $1}' | tr -d :)
    case "$dev" in
        ${TARGET_DISK}*) continue ;;
    esac
    size=$(blockdev --getsize64 "$dev" 2>/dev/null || echo 0)
    echo "$size $(echo "$line" | grep -oP 'UUID="\K[^"]+')"
done | sort -rn | awk 'NR==1{print $2}')

# Find the largest ext4 partition that ISN'T on the target disk and
# also isn't the EFI partition — that's our sibling Linux root.
SIB_UUID=$(blkid -t TYPE=ext4 | while read line; do
    dev=$(echo "$line" | awk '{print $1}' | tr -d :)
    case "$dev" in
        ${TARGET_DISK}*) continue ;;
    esac
    size=$(blockdev --getsize64 "$dev" 2>/dev/null || echo 0)
    echo "$size $(echo "$line" | grep -oP 'UUID="\K[^"]+')"
done | sort -rn | awk 'NR==1{print $2}')

if [ -n "$WIN_UUID" ]; then
    sed -i -E "s|^(  windowsNtfsUUID = )\".*\";|\\1\"$WIN_UUID\";|" "$REPO/mounts.nix"
    echo "   Windows UUID : $WIN_UUID"
fi
if [ -n "$SIB_UUID" ]; then
    sed -i -E "s|^(  cachyOsRootUUID = )\".*\";|\\1\"$SIB_UUID\";|" "$REPO/mounts.nix"
    echo "   Sibling UUID : $SIB_UUID"
fi

# -----------------------------------------------------------
# INSTALL
# -----------------------------------------------------------
echo "→ Running nixos-install --flake .#${TARGET_DE}"
cd "$REPO"
nixos-install --flake ".#${TARGET_DE}" --no-root-password

# -----------------------------------------------------------
# COPY THE REPO ONTO THE NEW SYSTEM SO IT'S AVAILABLE POST-REBOOT
# -----------------------------------------------------------
mkdir -p /mnt/home/todd/Documents/GitHub
rsync -a --exclude='.git' "$REPO/" \
      "/mnt/home/todd/Documents/GitHub/iBP-Nix-Install/"
# Also clone iBP-Nix-Swap (sister repo) so the user has the day-to-day
# DE-swap tooling available immediately after first boot.
if [ ! -d "/tmp/iBP-Nix-Swap" ]; then
    git clone --depth 1 https://github.com/Todd0042/iBP-Nix-Swap.git \
        /tmp/iBP-Nix-Swap || true
fi
if [ -d "/tmp/iBP-Nix-Swap/.git" ] || [ -d "/tmp/iBP-Nix-Swap" ]; then
    rsync -a --exclude='.git' "/tmp/iBP-Nix-Swap/" \
          "/mnt/home/todd/Documents/GitHub/iBP-Nix-Swap/"
fi
chown -R 1000:100 /mnt/home/todd/Documents 2>/dev/null || true

# -----------------------------------------------------------
# OPTIONAL: RESTORE A SNAPSHOT
# -----------------------------------------------------------
if [ -n "$RESTORE_SNAP" ] && [ -f "$RESTORE_SNAP" ]; then
    echo "→ Restoring home snapshot $RESTORE_SNAP into /mnt/home/todd/.persist"
    mkdir -p /mnt/home/todd/.persist
    nixos-enter --root /mnt -- \
        bash /home/todd/Documents/GitHub/iBP-Nix-Install/scripts/restore-home.sh \
            "$RESTORE_SNAP" || true
fi

echo ""
echo "==============================================="
echo "  INSTALL COMPLETE — reboot."
echo "  Default password: meow   (change with passwd)"
echo "==============================================="
