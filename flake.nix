# iBP-Nix-Install — initial-install variant of iBP-Nix-Swap
#
# Targets:
#   sudo nixos-install --flake .#kde            # used by ./bootstrap.sh
#   nix build .#nixosConfigurations.installer.config.system.build.isoImage
#                                                # build the live ISO
#
# Once installed, you should `git clone iBP-Nix-Swap` for ongoing day-to-day
# DE swapping. This flake intentionally mirrors iBP-Nix-Swap so the install
# environment matches the post-install environment 1:1.

{
  description = "iBP-Nix-Install — initial-install NixOS flake for Todd's daily driver";

  inputs = {
    nixpkgs.url          = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs:
  let
    system = "x86_64-linux";

    unstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };
    commonArgs = { inherit inputs unstable; };

    # The installer script copies hardware-configuration.nix into the repo
    # before invoking nixos-install, so these will exist by then. We also
    # check pathExists so the targets evaluate cleanly in CI / a fresh clone.
    hwModule  = if builtins.pathExists ./hardware-configuration.nix
                then [ ./hardware-configuration.nix ] else [];
    gpuModule = if builtins.pathExists ./gpu.nix
                then [ ./gpu.nix ] else [];

    sharedModules = [
      ./configuration.nix
      ./dev.nix
      ./tray-fix.nix
      ./persist.nix
      ./mounts.nix
      home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs       = true;
        home-manager.useUserPackages     = true;
        home-manager.extraSpecialArgs    = commonArgs;
        home-manager.users.todd          = import ./home.nix;
        home-manager.backupFileExtension = "backup";
      }
    ] ++ hwModule ++ gpuModule;

    mkSystem = deModule:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = commonArgs;
        modules     = sharedModules ++ (if deModule == null then [] else [ deModule ]);
      };
  in {
    nixosConfigurations = {
      kde       = mkSystem ./desktops/kde.nix;
      xfce      = mkSystem ./desktops/xfce.nix;
      hypr      = mkSystem ./desktops/hyprland.nix;
      i3        = mkSystem ./desktops/i3.nix;
      gnome     = mkSystem ./desktops/gnome.nix;
      cinnamon  = mkSystem ./desktops/cinnamon.nix;
      cosmic    = mkSystem ./desktops/cosmic.nix;
      lxqt      = mkSystem ./desktops/lxqt.nix;
      sway      = mkSystem ./desktops/sway.nix;
      "kde-hypr"= mkSystem ./desktops/kde-hypr.nix;
      cli       = mkSystem null;

      # Live-install ISO: boot this, run /etc/iBP-Nix-Install/bootstrap.sh
      installer = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = commonArgs;
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ./iso-installer.nix
        ];
      };
    };
  };
}
