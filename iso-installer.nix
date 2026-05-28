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

  # ISO-side packages: just enough for bootstrap.sh + install-core.sh
  environment.systemPackages = lib.mkAfter (with pkgs; [
    bash coreutils util-linux
    parted gptfdisk
    networkmanager iwd curl wget git
    lshw pciutils
    btrfs-progs ntfs3g exfatprogs
    rsync
    zstd
  ]);

  # Embed the bootstrap scripts into the ISO at a known path. After boot,
  # the user runs:    sudo /etc/iBP-Nix-Install/bootstrap.sh
  environment.etc."iBP-Nix-Install/bootstrap.sh".source     = ./scripts/bootstrap.sh;
  environment.etc."iBP-Nix-Install/install-core.sh".source  = ./scripts/install-core.sh;
  environment.etc."iBP-Nix-Install/post-install.sh".source  = ./scripts/post-install.sh;
}
