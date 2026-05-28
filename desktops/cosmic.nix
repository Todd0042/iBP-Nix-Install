# cosmic.nix
{ config, pkgs, ... }:
{
  system.nixos.label = "COSMIC";

  services.desktopManager.cosmic.enable          = true;
  services.displayManager.cosmic-greeter.enable  = true;

  xdg.portal.extraPortals = with pkgs; [
    xdg-desktop-portal-cosmic
    xdg-desktop-portal-gtk
  ];

  environment.systemPackages = with pkgs; [
    cosmic-icons
    libnotify
  ];
}
