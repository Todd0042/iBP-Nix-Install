# kde-hypr.nix — both Plasma 6 AND Hyprland available at the SDDM login.
# Choose your session from the gear menu on the login screen.
{ config, pkgs, ... }:
{
  system.nixos.label = "KDE-PLASMA-6 + HYPRLAND";

  imports = [ ./sddm.nix ];

  services.desktopManager.plasma6.enable = true;
  programs.hyprland = { enable = true; xwayland.enable = true; };

  # Default to Plasma X11 (best for GW2). Hyprland and Plasma-Wayland
  # are still selectable from SDDM's gear menu.
  services.displayManager.defaultSession = "plasmax11";

  xdg.portal.extraPortals = with pkgs; [
    kdePackages.xdg-desktop-portal-kde
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
  ];

  security.polkit.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL              = "1";
    GBM_BACKEND                 = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME   = "nvidia";
    LIBVA_DRIVER_NAME           = "nvidia";
    MOZ_ENABLE_WAYLAND          = "1";
  };
  environment.variables = { WLR_NO_HARDWARE_CURSORS = "1"; };

  environment.systemPackages = with pkgs; [
    kdePackages.discover
    kdePackages.konsole
    kdePackages.dolphin
    kdePackages.dolphin-plugins
    kdePackages.ark
    kdePackages.kcalc
    kdePackages.sddm-kcm
    kdePackages.plasma-systemmonitor

    waybar wofi mako swaylock-effects swayidle swww
    grim slurp wl-clipboard cliphist
    pavucontrol networkmanagerapplet polkit-kde-agent

    libnotify
  ];
}
