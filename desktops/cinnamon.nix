# cinnamon.nix
{ config, pkgs, ... }:
{
  system.nixos.label = "CINNAMON";

  services.xserver.enable                          = true;
  services.xserver.displayManager.lightdm.enable   = true;
  services.xserver.desktopManager.cinnamon.enable  = true;

  xdg.portal.extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
  programs.dconf.enable   = true;

  environment.systemPackages = with pkgs; [
    nemo
    libnotify
  ];
}
