# iBP-Nix-Install

Initial-install variant of [iBP-Nix-Swap](../iBP-Nix-Swap). Builds a live
ISO whose only job is to partition your **second NVMe** (PNY CS2241,
`/dev/nvme1n1` by default), drop NixOS on it, and leave the first NVMe
(Windows + CachyOS) untouched.

## What the install lays down

By the time `nixos-install` finishes you have:

- NixOS 25.11 with the same configuration.nix as iBP-Nix-Swap
- KDE Plasma 6 (or any other target you picked) ready at SDDM
- All of `dev.nix` installed: cmake, mingw cross-compile, Rust, Go,
  Python, Node, **Claude Code CLI**, official Microsoft VS Code, Ollama,
  Helix, lazygit, gh, etc.
- The user `todd` with password `meow` (change on first login)
- `~/Windows` mounted to your existing Windows NTFS partition
- `~/CachyOS` mounted to your existing CachyOS root (read-only)
- This repo cloned at `~/Documents/GitHub/iBP-Nix-Install/` for later
  rebuilds
- `~/.persist/` directory ready to receive your snapshot

## Disk plan

```
nvme0n1 (ADATA, 931 GB)    ← UNTOUCHED
   ├ p1 EFI                 (Windows boot)
   ├ p3 NTFS Recovery
   ├ p4 NTFS Windows        → mounted at ~/Windows  (rw)
   ├ p5 vfat /boot/efi      (CachyOS boot)
   └ p6 ext4 /              → mounted at ~/CachyOS  (ro)

nvme1n1 (PNY, 931 GB)      ← WIPED + repartitioned
   ├ p1 vfat 2 GiB          /boot   (NixOS ESP)
   └ p2 ext4 remainder      /       (NixOS root)
```

> ⚠ **Warning:** nvme1n1 currently holds a 931 GB NTFS "Shared" partition
> mounted at `/home/todd/Shared`. The installer wipes it. Move anything
> you need off it first — e.g. to the Samsung T5 external (`/dev/sda`) or
> into `~/CachyOS` via `~/Shared` symlinks before reboot.

## Bootflow

NixOS' EFI partition goes on nvme1n1p1, so the installer doesn't touch
the existing Windows / CachyOS boot entries. After install:

- Press F11 (or your motherboard's UEFI hotkey) at POST to pick between
  Windows EFI, CachyOS GRUB, and the new "NixOS Boot Manager" entry.
- Or, in CachyOS: `sudo grub-mkconfig -o /boot/grub/grub.cfg` — os-prober
  will find the NixOS entry and add it to GRUB.

## Building the ISO

From any working Nix host (the existing CachyOS install, or another
NixOS box):

```bash
cd ~/Documents/GitHub/iBP-Nix-Install

# Build the live installer ISO
nix build .#nixosConfigurations.installer.config.system.build.isoImage

# Result symlinked at ./result/iso/*.iso
ls -lh ./result/iso/
```

Burn to USB with Ventoy (already in your iBP-Nix-Swap package set) or
`dd` if you want a single-purpose stick.

## Running the install

Boot the ISO, then:

```bash
sudo /etc/iBP-Nix-Install/bootstrap.sh
```

It walks you through:

1. Disk pick (default `/dev/nvme1n1`)
2. DE pick (default `kde`)
3. Confirmation (with summary)
4. Partition + format + nixos-install
5. Auto-fills `mounts.nix` with the discovered Windows + CachyOS UUIDs
6. Copies this repo + iBP-Nix-Swap into `/mnt/home/todd/Documents/GitHub/`

For one-shot, scripted installs:

```bash
sudo /etc/iBP-Nix-Install/bootstrap.sh --auto kde \
     --disk /dev/nvme1n1 \
     --restore /run/media/usb/home-snapshot-2026-05-28.tar.zst
```

## Carrying your state across the install

Workflow:

```bash
# On the OLD system (CachyOS or previous NixOS), before reinstall:
./scripts/snapshot-home.sh /run/media/usb/    # writes ~600 MB tarball

# After install + reboot, on the new system:
~/Documents/GitHub/iBP-Nix-Install/scripts/restore-home.sh \
    /run/media/usb/home-snapshot-*.tar.zst
sudo ~/Documents/GitHub/iBP-Nix-Install/scripts/swap.sh kde
# log out / back in → Firefox, Vesktop, Claude Code, VS Code etc. all logged in.
```

If you passed `--restore` to bootstrap, this is done for you during the
install — first boot already has everything wired up.

## Day-to-day after install

```bash
# Switch DE
sudo ~/Documents/GitHub/iBP-Nix-Install/scripts/swap.sh xfce

# Or fork iBP-Nix-Swap for ongoing tweaking and use that
```

The repos are mirror images on purpose: anything you change in one can be
copied over to the other.
