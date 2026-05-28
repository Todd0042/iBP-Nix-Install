# i3.nix — i3 + polybar + picom + rofi on X11
{ config, pkgs, ... }:
{
  system.nixos.label = "I3WM";

  # LightDM works well with i3 (SDDM tends to grab Wayland session by default)
  services.xserver.displayManager.lightdm = {
    enable = true;
    greeters.gtk = {
      enable = true;
      theme.name = "Catppuccin-Mocha-Standard-Blue-Dark";
    };
    background = "/etc/xdg/wallpapers/wall-1.png";
  };

  services.displayManager.defaultSession = "none+i3";

  services.xserver = {
    enable = true;
    xkb = { layout = "us"; variant = ""; };

    windowManager.i3 = {
      enable      = true;
      extraPackages = with pkgs; [
        dmenu i3status i3lock i3blocks
      ];
    };
  };

  programs.dconf.enable  = true;
  security.polkit.enable = true;

  xdg.portal.extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];

  environment.systemPackages = with pkgs; [
    # i3 ecosystem
    rofi
    polybar
    picom
    feh                          # wallpaper setter
    dunst                        # notifications
    autorandr                    # monitor profiles
    arandr                       # GUI version
    flameshot                    # screenshot
    redshift                     # blue-light filter
    xfce.thunar                  # consistent file manager
    networkmanagerapplet
    blueman                      # bluetooth tray
    pavucontrol
    pasystray
    volumeicon
    xss-lock                     # idle locker glue
    xorg.xbacklight
    xclip
    xdotool
    playerctl
    libnotify
  ];

  # systemd user services started by i3 autostart (handy for the keybind
  # overlay's Python runtime)
  environment.pathsToLink = [ "/share/applications" ];
}
