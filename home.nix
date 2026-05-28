# home.nix — home-manager profile for todd
{ config, pkgs, lib, ... }:

{
  home.username      = "todd";
  home.homeDirectory = "/home/todd";
  home.stateVersion  = "25.11";

  programs.home-manager.enable = true;

  # Most of the DE-specific dotfiles live in this repo. We use out-of-store
  # symlinks for hyprland + i3 + waybar so you can edit configs and reload
  # them without a full nixos-rebuild — handy when iterating on a tiling WM.
  home.file = {
    # ── KDE Plasma (versioned config snapshots, restored on swap-back) ──
    ".config/kdeglobals".source         = ./dotfiles/kde/kdeglobals.stable;
    ".config/plasmarc".source           = ./dotfiles/kde/plasmarc.stable;
    ".config/kcminputrc".source         = ./dotfiles/kde/kcminputrc.stable;
    ".config/kscreenlockerrc".source    = ./dotfiles/kde/kscreenlockerrc.stable;
    ".config/kglobalshortcutsrc".source = ./dotfiles/kde/kglobalshortcutsrc.stable;
    ".config/kwinrulesrc".source        = ./dotfiles/kde/kwinrulesrc.stable;
    ".icons/default/index.theme".source = ./dotfiles/kde/index.theme.stable;

    ".config/plasma-org.kde.plasma.desktop-appletsrc" = {
      source = ./dotfiles/kde/plasma-appletsrc.stable;
      force  = true;
    };

    # ── Terminal & shell ──
    ".config/alacritty/alacritty.toml".source = ./dotfiles/alacritty/alacritty.toml;
    ".config/fish/config.fish".source         = ./dotfiles/fish/config.fish;
    ".config/fish/10.jsonc".source            = ./dotfiles/fish/10.jsonc;
    ".config/fish/done.fish".source           = ./dotfiles/fish/done.fish;

    # ── Wallpapers ──
    "Pictures/customizations/wall-1.png".source = ./customizations/wall-1.png;
    "Pictures/customizations/wall-2.png".source = ./customizations/wall-2.png;
    "Pictures/customizations/nix.png".source    = ./customizations/nix.png;

    # ── Tiling WM configs (out-of-store: edit & reload, no rebuild) ──
    # Path is fixed to where the flake is checked out. If you ever move the
    # repo, update the path here too.
    ".config/hypr".source = config.lib.file.mkOutOfStoreSymlink
      "/home/todd/Documents/GitHub/iBP-Nix-Install/dotfiles/hyprland";

    ".config/waybar".source = config.lib.file.mkOutOfStoreSymlink
      "/home/todd/Documents/GitHub/iBP-Nix-Install/dotfiles/hyprland/waybar";

    ".config/i3".source = config.lib.file.mkOutOfStoreSymlink
      "/home/todd/Documents/GitHub/iBP-Nix-Install/dotfiles/i3";

    ".config/polybar".source = config.lib.file.mkOutOfStoreSymlink
      "/home/todd/Documents/GitHub/iBP-Nix-Install/dotfiles/i3/polybar";

    ".config/rofi".source = config.lib.file.mkOutOfStoreSymlink
      "/home/todd/Documents/GitHub/iBP-Nix-Install/dotfiles/i3/rofi";

    ".config/picom/picom.conf".source = ./dotfiles/i3/picom.conf;
  };

  home.packages = with pkgs; [
    home-manager
    fastfetch
    htop
  ];
}
