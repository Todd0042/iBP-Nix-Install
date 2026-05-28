# xfce.nix — XFCE 4 with the SNI tray fix baked in
{ config, pkgs, ... }:
{
  system.nixos.label = "XFCE-4";

  # LightDM here (XFCE's traditional pair) instead of SDDM. Avoids the
  # plasma-tied SDDM theme overriding our XFCE login background.
  services.xserver.displayManager.lightdm = {
    enable = true;
    greeters.gtk = {
      enable = true;
      theme.name = "Catppuccin-Mocha-Standard-Blue-Dark";
    };
    background = "/etc/xdg/wallpapers/wall-1.png";
  };

  services.xserver.enable                = true;
  services.xserver.desktopManager.xfce.enable = true;

  services.xserver.xkb = {
    layout  = "us";
    variant = "";
  };

  programs.dconf.enable = true;

  # GTK portal is the only one XFCE needs natively
  xdg.portal.extraPortals = with pkgs; [
    xdg-desktop-portal-gtk
  ];

  # The XFCE-specific tray glue. tray-fix.nix already adds
  # xfce4-statusnotifier-plugin system-wide; here we also pull in the
  # commonly-used panel extras + dock so the post-swap experience matches.
  environment.systemPackages = with pkgs; [
    xfce.xfce4-panel
    xfce.xfce4-panel-profiles
    xfce.xfce4-statusnotifier-plugin   # ★ the disappearing-icon fix
    xfce.xfce4-pulseaudio-plugin
    xfce.xfce4-systemload-plugin
    xfce.xfce4-clipman-plugin
    xfce.xfce4-cpugraph-plugin
    xfce.xfce4-netload-plugin
    xfce.xfce4-screenshooter
    xfce.xfce4-taskmanager
    xfce.xfce4-whiskermenu-plugin
    xfce.thunar-archive-plugin
    xfce.thunar-volman
    xfce.tumbler                       # thumbnails
    xfce.xfce4-notifyd
    xfce.xfce4-power-manager

    networkmanagerapplet
    pavucontrol
    plank                              # optional dock
    libnotify
    bluez
  ];

  # XFCE doesn't auto-start NetworkManager applet — add it via XDG autostart.
  environment.etc."xdg/autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Network
    Exec=nm-applet
    OnlyShowIn=XFCE;
    X-GNOME-Autostart-Phase=Initialization
  '';
}
