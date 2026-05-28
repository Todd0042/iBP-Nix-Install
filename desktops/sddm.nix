# sddm.nix — shared display manager config for all DEs that use SDDM
{ pkgs, ... }:
{
  services.displayManager.sddm = {
    enable        = true;
    wayland.enable = true;
    settings = {
      Theme = {
        CursorTheme = "Nordzy-green-dark";
      };
    };
  };

  # SDDM-rendered background. Wallpaper is installed system-wide by
  # configuration.nix via environment.etc."xdg/wallpapers/wall-1.png".
  environment.etc."opt/sddm/theme/theme.conf.user".text = ''
    [General]
    background=/etc/xdg/wallpapers/wall-1.png
  '';

  # The wallpapers + KDE config snapshots are referenced by both SDDM and
  # the system tray of every DE — installing them at /etc/xdg/ means GTK
  # apps, SDDM, and a clean account all see the same defaults.
  environment.etc = {
    "xdg/wallpapers/wall-1.png".source     = ../customizations/wall-1.png;
    "xdg/wallpapers/wall-2.png".source     = ../customizations/wall-2.png;
    "xdg/icons/nix-launcher.png".source    = ../customizations/nix.png;
  };
}
