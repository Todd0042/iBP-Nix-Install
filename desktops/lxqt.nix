# lxqt.nix
{ config, pkgs, ... }:
{
  system.nixos.label = "LXQT";

  services.xserver.enable                          = true;
  services.xserver.displayManager.lightdm.enable   = true;
  services.xserver.desktopManager.lxqt.enable      = true;

  xdg.portal.extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];

  environment.systemPackages = with pkgs; [
    networkmanagerapplet
    pavucontrol
    libnotify
  ];
}
