# kde.nix — Plasma 6, X11 session default (Wayland still selectable)
#
# Why X11 default: Guild Wars 2's launcher uses Win32 layered-window
# transparency, which XWayland renders poorly. Native X11 makes the
# launcher render correctly and gives noticeably better in-game frametimes
# on this user's NVIDIA card. The Wayland session stays available from
# the gear menu on the SDDM login screen.
{ config, pkgs, ... }:
{
  system.nixos.label = "KDE-PLASMA-6";

  imports = [ ./sddm.nix ];

  services.desktopManager.plasma6.enable = true;

  # Default SDDM session = Plasma X11. Pick "Plasma (Wayland)" from the
  # gear menu when you want Wayland (e.g. fractional scaling testing).
  services.displayManager.defaultSession = "plasmax11";

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

    # extra KDE apps from pacman list
    kdePackages.kate
    kdePackages.kdeconnect-kde
    kdePackages.kdegraphics-thumbnailers
    kdePackages.ffmpegthumbs            # video file thumbnails in Dolphin
    kdePackages.kdialog
    kdePackages.kinfocenter
    kdePackages.kscreen
    kdePackages.kwalletmanager
    kdePackages.spectacle               # screenshot tool
    kdePackages.gwenview                # image viewer
    kdePackages.bluedevil               # Bluetooth integration
    kdePackages.plasma-thunderbolt
    kdePackages.kde-gtk-config          # GTK theme integration
    kdePackages.plasma-firewall
    kdePackages.breeze-gtk              # GTK Breeze theme parity
    kdePackages.phonon-vlc              # Phonon backend (was phonon-qt6-vlc)

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

    # GStreamer plugin stack — used by Plasma / Dolphin previews + Haruna
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
    gst_all_1.gst-vaapi

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
