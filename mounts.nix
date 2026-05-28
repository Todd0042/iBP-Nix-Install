# mounts.nix — bind sibling OSes into ~/ for easy file access.
#
# Layout assumption (post-install):
#
#   nvme0n1  (ADATA LEGEND 860, 931 GB) — multi-boot disk, untouched
#     p1  EFI                                — Windows boot
#     p3  Recovery (NTFS)                    — Windows recovery
#     p4  Windows  (NTFS)                    → mounted at /home/todd/Windows
#     p5  /boot/efi (vfat)                   — CachyOS boot (also fine to chain)
#     p6  / (ext4)                           → mounted at /home/todd/CachyOS  (ro)
#
#   nvme1n1  (PNY CS2241, 931 GB)            — DEDICATED to NixOS
#     p1  /boot (vfat, EFI)                  — handled by hardware-configuration.nix
#     p2  / (ext4)                           — handled by hardware-configuration.nix
#
#   sda      (Samsung T5 EVO, 1.8 TB)        — external backup (auto-mounts when plugged)
#
# UUIDs below are read from the *current* disks. The CachyOS root UUID was
# pulled from /etc/fstab on the live CachyOS install. The Windows UUID comes
# from `sudo blkid /dev/nvme0n1p4`. If you reformat or repartition any disk,
# re-run scripts/discover-mounts.sh to refresh this file.

{ config, lib, pkgs, ... }:

let
  # ───── Mount UUIDs ──────────────────────────────────────────────
  # CachyOS root (ext4) — from existing /etc/fstab on nvme0n1p6
  cachyOsRootUUID = "b2fa9481-a53c-424a-8bc1-fb79c1c61552";

  # Windows NTFS (nvme0n1p4). PLACEHOLDER until you run discover-mounts.sh.
  # If left blank, the Windows mount entry is skipped — no boot failure.
  windowsNtfsUUID = "724C784C4C780CDB";   # ← run: sudo blkid /dev/nvme0n1p4 → copy UUID here

  # ───── Common options ──────────────────────────────────────────
  # `nofail`:               don't block boot if the disk is missing
  # `x-systemd.automount`:  lazy-mount on first access (faster boot)
  # `x-systemd.idle-timeout`: unmount after inactivity (safer for ntfs3)
  ntfsOpts = [
    "nofail"
    "rw"
    "uid=1000" "gid=100"
    "umask=022"
    "iocharset=utf8"
    "windows_names"
    "x-systemd.automount"
    "x-systemd.idle-timeout=60"
  ];

  ext4ReadOnlyOpts = [
    "nofail"
    "ro"               # read-only — it's another distro's root, don't write
    "noatime"
    "x-systemd.automount"
    "x-systemd.idle-timeout=60"
  ];
in
{
  # Filesystem driver support
  boot.supportedFilesystems = [ "ntfs" "exfat" "ext4" "vfat" ];

  # Ensure the mount-point dirs exist with the right owner.
  systemd.tmpfiles.rules = [
    "d /home/todd/Windows 0755 todd users -"
    "d /home/todd/CachyOS 0755 todd users -"
  ];

  fileSystems = lib.mkMerge [
    # CachyOS root — always defined (UUID is known).
    {
      "/home/todd/CachyOS" = {
        device  = "/dev/disk/by-uuid/${cachyOsRootUUID}";
        fsType  = "ext4";
        options = ext4ReadOnlyOpts;
      };
    }

    # Windows — only defined when UUID has been filled in.
    (lib.mkIf (windowsNtfsUUID != "") {
      "/home/todd/Windows" = {
        device  = "/dev/disk/by-uuid/${windowsNtfsUUID}";
        fsType  = "ntfs3";
        options = ntfsOpts;
      };
    })
  ];
}
