# sway.nix — wlroots-based, simpler/cleaner than Hyprland for NVIDIA
# (works but slower than Hyprland on NVIDIA; useful as a fallback)
{ config, pkgs, ... }:
{
  system.nixos.label = "SWAY";

  imports = [ ./sddm.nix ];

  programs.sway = {
    enable      = true;
    wrapperFeatures.gtk = true;
  };

  security.polkit.enable = true;
  xdg.portal.extraPortals = with pkgs; [
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL    = "1";
    MOZ_ENABLE_WAYLAND = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  environment.systemPackages = with pkgs; [
    waybar
    wofi
    mako
    swaylock-effects
    swayidle
    swww
    grim slurp
    wl-clipboard
    cliphist
    pavucontrol
    networkmanagerapplet
    polkit-kde-agent
  ];
}
