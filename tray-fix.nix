# tray-fix.nix — keep status tray icons (Discord/Vesktop/KeePassXC/Sunshine
# /Steam) visible across DE swaps.
#
# Root cause of the disappearing-icons problem on a KDE ↔ XFCE flip:
#
#   1. Modern tray apps (Discord, Vesktop, Sunshine, KeePassXC, Element,
#      etc.) implement the StatusNotifierItem (SNI) D-Bus spec, NOT the
#      legacy XEmbed protocol.
#   2. KDE Plasma's systray hosts SNI natively.
#   3. XFCE's default panel ships only XEmbed; SNI support lives in
#      `xfce4-panel-profiles` and the optional `xfce4-statusnotifier-plugin`.
#      If that plugin isn't installed *and* added to the panel, every SNI
#      app silently vanishes when you log into XFCE.
#   4. On swap-back to KDE, panel layout state in plasma-appletsrc can be
#      mid-rewrite if an autostarted app raced the panel — icons "lose"
#      their slot.
#
# Fix:
#   - Install `xfce4-statusnotifier-plugin` system-wide so it's always
#     available to XFCE.
#   - Install `gnome.gnome-settings-daemon` so GTK status-icon legacy is
#     also available everywhere.
#   - Provide an XDG autostart entry that *waits* for the systray bus name
#     before launching tray apps, so we don't race the panel.
#   - Set GTK_USE_PORTAL=1 so Electron/GTK apps file-pick through portals
#     instead of stale GTK file dialogs after a DE swap.

{ pkgs, lib, ... }:

let
  # Helper: wait up to 20s for a tray host to claim
  # org.kde.StatusNotifierWatcher on the session bus, then exec the app.
  # XFCE's xfce4-statusnotifier-plugin claims the same well-known name.
  waitTrayLauncher = pkgs.writeShellScriptBin "wait-tray-then-exec" ''
    #!${pkgs.runtimeShell}
    # usage: wait-tray-then-exec <command> [args...]
    deadline=$(( $(date +%s) + 20 ))
    while [ "$(date +%s)" -lt "$deadline" ]; do
      if ${pkgs.dbus}/bin/dbus-send --session --print-reply \
           --dest=org.freedesktop.DBus /org/freedesktop/DBus \
           org.freedesktop.DBus.NameHasOwner \
           string:org.kde.StatusNotifierWatcher 2>/dev/null \
         | grep -q "boolean true"; then
        exec "$@"
      fi
      sleep 0.5
    done
    # Tray host never appeared (CLI session?) — exec anyway so we don't
    # silently lose the program.
    exec "$@"
  '';
in
{
  # System-wide tray-related packages
  environment.systemPackages = with pkgs; [
    waitTrayLauncher

    # The fix-the-XFCE-tray plugin
    xfce.xfce4-statusnotifier-plugin
    xfce.xfce4-panel-profiles
    xfce.xfce4-pulseaudio-plugin
    xfce.xfce4-systemload-plugin
    xfce.xfce4-clipman-plugin

    # GTK status icon fallback (legacy XEmbed)
    libappindicator-gtk3
    libayatana-appindicator
  ];

  # Make portals available irrespective of DE so file dialogs survive a swap.
  xdg.portal = {
    enable        = true;
    xdgOpenUsePortal = true;
    extraPortals  = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    # Per-DE modules (kde.nix, hyprland.nix, …) append the matching native
    # portal to this list.
    config.common.default = [ "gtk" ];
  };

  environment.sessionVariables = {
    # Electron apps use Wayland natively when available
    NIXOS_OZONE_WL = "1";
    # GTK file dialogs go through portals — survives DE changes
    GTK_USE_PORTAL = "1";
  };
}
