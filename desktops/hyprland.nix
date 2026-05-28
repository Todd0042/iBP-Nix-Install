# hyprland.nix — Hyprland with NVIDIA-friendly env + waybar + helpers
{ config, pkgs, ... }:
{
  system.nixos.label = "HYPRLAND";

  imports = [ ./sddm.nix ];

  programs.hyprland = {
    enable          = true;
    xwayland.enable = true;
  };

  security.polkit.enable = true;

  xdg.portal.extraPortals = with pkgs; [
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
  ];

  # Hyprland on NVIDIA needs these.
  environment.sessionVariables = {
    NIXOS_OZONE_WL              = "1";
    GBM_BACKEND                 = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME   = "nvidia";
    LIBVA_DRIVER_NAME           = "nvidia";
    MOZ_ENABLE_WAYLAND          = "1";
    QT_QPA_PLATFORM             = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    SDL_VIDEODRIVER             = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    XCURSOR_SIZE                = "24";
    XDG_CURRENT_DESKTOP         = "Hyprland";
    XDG_SESSION_TYPE            = "wayland";
    XDG_SESSION_DESKTOP         = "Hyprland";
  };

  environment.variables = {
    WLR_NO_HARDWARE_CURSORS = "1";   # required on NVIDIA + Hyprland still
  };

  environment.systemPackages = with pkgs; [
    waybar
    wofi rofi-wayland
    mako                      # notification daemon
    swww                      # wallpaper daemon
    swaylock-effects
    swayidle
    grim slurp                # screenshot
    wl-clipboard
    cliphist
    brightnessctl
    playerctl
    pamixer
    pavucontrol
    networkmanagerapplet
    polkit-kde-agent
    xdg-utils
    file-manager-actions
    kdePackages.dolphin       # consistent file manager across DEs
    kdePackages.konsole
    libnotify
    qt6.qtwayland
  ];
}
