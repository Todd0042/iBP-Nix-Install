# kde.nix — Plasma 6 on Wayland (default)
{ config, pkgs, ... }:
{
  system.nixos.label = "KDE-PLASMA-6";

  imports = [ ./sddm.nix ];

  services.desktopManager.plasma6.enable = true;

  # Native KDE portal — appended onto the gtk fallback from tray-fix.nix
  xdg.portal.extraPortals = with pkgs; [
    kdePackages.xdg-desktop-portal-kde
  ];

  security.polkit.enable = true;

  environment.systemPackages = with pkgs; [
    # core KDE apps you actually use
    kdePackages.discover
    kdePackages.konsole
    kdePackages.dolphin
    kdePackages.dolphin-plugins
    kdePackages.kio-admin
    kdePackages.ark
    kdePackages.kcalc
    kdePackages.kdenlive
    kdePackages.kcharselect
    kdePackages.kclock
    kdePackages.kcolorchooser
    kdePackages.kolourpaint
    kdePackages.ksystemlog
    kdePackages.sddm-kcm
    kdePackages.isoimagewriter
    kdePackages.partitionmanager
    kdePackages.yakuake
    kdePackages.filelight
    kdePackages.plasma-systemmonitor

    # plasma widgets / shell extras
    kdePackages.plasma-desktop
    kdePackages.plasma-nm
    kdePackages.libplasma
    kdePackages.plasma-workspace
    kdePackages.kdeplasma-addons
    kdePackages.plasma-activities
    kdePackages.plasma-integration
    kdePackages.plasma-browser-integration
    kdePackages.plasma-workspace-wallpapers

    kdiff3
    libnotify
  ];

  # System-wide KDE theming source-of-truth (mirrored from this repo)
  # — so a fresh login with no home-manager state still looks right.
  environment.etc = {
    "xdg/kdeglobals".source                       = ../dotfiles/kde/kdeglobals.stable;
    "xdg/plasmarc".source                         = ../dotfiles/kde/plasmarc.stable;
    "xdg/kcminputrc".source                       = ../dotfiles/kde/kcminputrc.stable;
    "xdg/kscreenlockerrc".source                  = ../dotfiles/kde/kscreenlockerrc.stable;
    "xdg/plasma-org.kde.plasma.desktop-appletsrc".source =
      ../dotfiles/kde/plasma-appletsrc.stable;
    "xdg/icons/default/index.theme".source        = ../dotfiles/kde/index.theme.stable;
  };
}
