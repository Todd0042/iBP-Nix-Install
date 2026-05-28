# persist.nix — keep logged-in app state across DE swaps AND reinstalls.
#
# Design:
#   /home/todd/.persist/   ← single source of truth for app state
#       ├─ firefox/        ← ~/.mozilla/firefox       (logins, cookies, addons)
#       ├─ vesktop/        ← ~/.config/vesktop        (Discord login token)
#       ├─ discord/        ← ~/.config/discord
#       ├─ brave/          ← ~/.config/BraveSoftware
#       ├─ keepassxc/      ← ~/.config/keepassxc
#       ├─ obsidian/       ← ~/.config/obsidian       (vault list + settings)
#       ├─ vscode/         ← ~/.config/Code           (extensions, login)
#       ├─ claude/         ← ~/.claude                (auto-memory!)
#       ├─ github-desktop/ ← ~/.config/GitHub Desktop
#       ├─ steam/          ← ~/.local/share/Steam     (LOGIN ONLY — see below)
#       └─ qbittorrent/    ← ~/.config/qBittorrent
#
# How it works:
#   1. On every activation, this module ensures /home/todd/.persist exists.
#   2. For each target dir under ~/.config or ~/, if the home path does NOT
#      already exist or is already a symlink we own, we replace it with a
#      symlink into ~/.persist.
#   3. If the home path EXISTS and is real data (i.e. you logged in fresh
#      before adopting persist), we move it into ~/.persist first, then
#      symlink. This is the migrate-on-first-boot behaviour.
#
# Important: this only relinks dirs that exist in ~/.persist. If you haven't
# restored a snapshot yet, the apps create fresh state in ~/.config/... — and
# we'll move that into ~/.persist next boot if you opt in by deleting it.
#
# Backups: see scripts/snapshot-home.sh — captures everything below into a
# tarball you can carry across machines.
#
# Steam note: ONLY the login file (`config/loginusers.vdf` and
# `config/config.vdf`) is small enough to be worth persisting. Game library
# downloads stay on disk and re-link via Steam's library-folders dialog.

{ config, pkgs, lib, ... }:

let
  persistRoot = "/home/todd/.persist";

  # name = persist-subdir → home-relative target
  mappings = {
    firefox       = ".mozilla/firefox";
    vesktop       = ".config/vesktop";
    discord       = ".config/discord";
    brave         = ".config/BraveSoftware";
    vivaldi       = ".config/vivaldi";
    librewolf     = ".librewolf";
    keepassxc     = ".config/keepassxc";
    obsidian      = ".config/obsidian";
    vscode        = ".config/Code";
    vscode-fhs    = ".vscode";
    claude        = ".claude";
    "github-desktop" = ".config/GitHub Desktop";
    qbittorrent   = ".config/qBittorrent";
    sunshine-cfg  = ".config/sunshine";
    obs-studio    = ".config/obs-studio";
    thunderbird   = ".thunderbird";
    fish-vars     = ".config/fish/conf.d";
  };

  # Bash snippet for a single link. Idempotent.
  linkLine = name: target: ''
    src="${persistRoot}/${name}"
    dst="/home/todd/${target}"
    if [ -d "$src" ]; then
      # ensure parent dir exists
      mkdir -p "$(dirname "$dst")"
      if [ -L "$dst" ]; then
        # already a symlink — verify it points where we want
        if [ "$(readlink "$dst")" != "$src" ]; then
          rm -f "$dst"
          ln -s "$src" "$dst"
        fi
      elif [ -d "$dst" ]; then
        # existing real data: migrate into persist, then link
        if [ ! -d "$src" ] || [ -z "$(ls -A "$src" 2>/dev/null)" ]; then
          rm -rf "$src"
          mv "$dst" "$src"
          ln -s "$src" "$dst"
        fi
      elif [ ! -e "$dst" ]; then
        ln -s "$src" "$dst"
      fi
      chown -h todd:users "$dst" || true
    fi
  '';
in
{
  # systemd-tmpfiles ensures persist dirs exist on every boot
  systemd.tmpfiles.rules = [
    "d ${persistRoot} 0700 todd users -"
  ];

  # Activation script runs after home-manager applies its files,
  # so symlinks here override anything home-manager would have placed.
  system.activationScripts.persistLinks = {
    text = ''
      mkdir -p ${persistRoot}
      chown todd:users ${persistRoot} || true
      ${lib.concatStringsSep "\n"
         (lib.mapAttrsToList linkLine mappings)}
    '';
    deps = [];
  };
}
