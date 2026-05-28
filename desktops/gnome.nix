# gnome.nix
{ config, pkgs, ... }:
{
  system.nixos.label = "GNOME";

  services.xserver.enable                        = true;
  services.xserver.displayManager.gdm.enable     = true;
  services.xserver.desktopManager.gnome.enable   = true;

  xdg.portal.extraPortals = with pkgs; [ xdg-desktop-portal-gnome ];
  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    gnome-tweaks
    gnomeExtensions.appindicator
    gnomeExtensions.dash-to-dock
    gnomeExtensions.tray-icons-reloaded
    gnomeExtensions.user-themes
    gnomeExtensions.vitals
    libnotify
  ];
}
