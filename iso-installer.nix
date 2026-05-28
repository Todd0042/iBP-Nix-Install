# iso-installer.nix — ISO live environment used by `nix build .#installer`.
{ pkgs, lib, modulesPath, ... }:
{
  networking.networkmanager.enable = true;
  networking.wireless.iwd.enable   = true;

  users.users.nixos = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" ];
  };
  security.sudo.wheelNeedsPassword = false;
  services.getty.autologinUser     = "nixos";

  # ISO-side packages: just enough for bootstrap.sh + install-core.sh,
  # PLUS os-prober + ntfs3g so the FIRST grub-mkconfig (run during
  # nixos-install) detects the existing Windows EFI on nvme0n1p1 and
  # the CachyOS GRUB on nvme0n1p5. Without os-prober here, the install
  # would land with a single-OS NixOS GRUB menu and need a second
  # rebuild later to pick up the sibling OSes.
  environment.systemPackages = lib.mkAfter (with pkgs; [
    bash coreutils util-linux
    parted gptfdisk
    networkmanager iwd curl wget git
    lshw pciutils
    btrfs-progs ntfs3g exfatprogs
    rsync
    zstd
    os-prober                       # required for grub triple-boot detect
    grub2                           # makes grub-mkconfig + grub-probe usable
                                    # for diagnostic runs before nixos-install
  ]);

  # NTFS kernel module so os-prober can poke the Windows BCD on nvme0n1p4
  # without going through ntfs-3g's FUSE path.
  boot.supportedFilesystems = [ "ntfs" "exfat" ];

  # Embed the bootstrap scripts into the ISO at a known path. After boot,
  # the user runs:    sudo /etc/iBP-Nix-Install/bootstrap.sh
  environment.etc."iBP-Nix-Install/bootstrap.sh".source     = ./scripts/bootstrap.sh;
  environment.etc."iBP-Nix-Install/install-core.sh".source  = ./scripts/install-core.sh;
  environment.etc."iBP-Nix-Install/post-install.sh".source  = ./scripts/post-install.sh;
}
