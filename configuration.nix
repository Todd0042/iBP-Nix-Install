# configuration.nix — shared across every DE target
{ config, pkgs, inputs, unstable, ... }:

{
  # -----------------------------------------------------------
  # BOOT (GRUB, UEFI mode, with os-prober for Windows + CachyOS)
  # -----------------------------------------------------------
  boot.loader.systemd-boot.enable = false;

  boot.loader.grub = {
    enable                = true;
    device                = "nodev";          # UEFI install — no BIOS target
    efiSupport            = true;
    efiInstallAsRemovable = true;             # writes \EFI\BOOT\BOOTX64.EFI,
                                              # no NVRAM mutation needed
    useOSProber           = true;             # picks up Windows + CachyOS
    configurationLimit    = 20;
    default               = "saved";          # remember last choice
    gfxmodeEfi            = "auto";
    extraConfig = ''
      GRUB_SAVEDEFAULT=true
      GRUB_TIMEOUT=5
    '';
  };

  boot.loader.efi.canTouchEfiVariables = false;

  # os-prober is needed on every grub-mkconfig run, not just the first.
  # NixOS' grub module pulls it in when `useOSProber = true`, but we add
  # it + ntfs3g to systemPackages so a `nixos-rebuild` invoked from any
  # context (including failure-mode rescue) keeps Windows + CachyOS in
  # the generated menu. boot.supportedFilesystems "ntfs" / "exfat" is
  # already declared in mounts.nix — modules merge cleanly.
  environment.systemPackages = with pkgs; [ os-prober ntfs3g ];

  # CachyOS-tuned kernel is overkill here; zen is upstream and well-tested
  # against NVIDIA out-of-tree. Falls back to latest stable if you'd rather:
  #   boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # IOMMU + VFIO for future WinBoat / GPU passthrough work.
  # Safe to leave on — Intel VT-d just sits idle until a guest claims it.
  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
    "nvidia_drm.modeset=1"
  ];
  boot.kernelModules = [ "kvm-intel" "vfio_pci" "vfio_iommu_type1" "vfio" ];

  # -----------------------------------------------------------
  # NIX
  # -----------------------------------------------------------
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    download-buffer-size  = 3221225472;            # 3 GiB
    auto-optimise-store   = true;                  # dedupe identical store files
    trusted-users         = [ "root" "todd" ];
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  nix.gc = {
    automatic = true;
    dates     = "weekly";
    options   = "--delete-older-than 30d";         # was 7d — too aggressive
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "archiver-3.5.1"
    "ventoy-qt5-1.1.10"
  ];

  # -----------------------------------------------------------
  # ZRAM SWAP (free insurance under LLM / build pressure)
  # -----------------------------------------------------------
  zramSwap = {
    enable        = true;
    algorithm     = "zstd";
    memoryPercent = 50;
  };

  # -----------------------------------------------------------
  # NETWORK / LOCALE / TIME
  # -----------------------------------------------------------
  networking.hostName            = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone     = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS        = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT    = "en_US.UTF-8";
    LC_MONETARY       = "en_US.UTF-8";
    LC_NAME           = "en_US.UTF-8";
    LC_NUMERIC        = "en_US.UTF-8";
    LC_PAPER          = "en_US.UTF-8";
    LC_TELEPHONE      = "en_US.UTF-8";
    LC_TIME           = "en_US.UTF-8";
  };

  # -----------------------------------------------------------
  # GRAPHICS (gpu.nix layers NVIDIA-specifics on top)
  # -----------------------------------------------------------
  hardware.graphics = {
    enable      = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      nvidia-vaapi-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      libva
      libvdpau
    ];
  };

  # -----------------------------------------------------------
  # AUDIO (pipewire)
  # -----------------------------------------------------------
  services.pulseaudio.enable = false;
  security.rtkit.enable      = true;
  services.pipewire = {
    enable            = true;
    alsa.enable       = true;
    alsa.support32Bit = true;
    pulse.enable      = true;
  };

  # -----------------------------------------------------------
  # GAMING STACK
  # -----------------------------------------------------------
  programs.steam = {
    enable                       = true;
    remotePlay.openFirewall      = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable      = true;
  };
  programs.gamemode.enable  = true;
  programs.gamescope.enable = true;

  # -----------------------------------------------------------
  # USER + SHELL
  # -----------------------------------------------------------
  programs.fish.enable    = true;
  users.defaultUserShell  = pkgs.fish;

  users.users.todd = {
    isNormalUser    = true;
    description     = "Todd McFinnighan";
    extraGroups     = [ "networkmanager" "wheel" "uinput" "gamemode" "video"
                        "adbusers" "libvirtd" "kvm" "input" ];
    # Default password on a fresh install. Change immediately with `passwd`.
    initialPassword = "meow";
  };

  # -----------------------------------------------------------
  # GIT (Full = with bash completion, gitk, git-gui)
  # -----------------------------------------------------------
  programs.git = {
    enable  = true;
    package = pkgs.gitFull;
  };

  # -----------------------------------------------------------
  # FONTS
  # -----------------------------------------------------------
  fonts.packages = with pkgs; [
    ubuntu-classic
    font-awesome
    nerd-fonts.ubuntu-sans
    nerd-fonts.ubuntu-mono
    nerd-fonts.ubuntu
    nerd-fonts.droid-sans-mono
    nerd-fonts.jetbrains-mono
    lexend
    jetbrains-mono
    noto-fonts
    noto-fonts-emoji
  ];

  # -----------------------------------------------------------
  # PRINTING / BLUETOOTH / AVAHI
  # -----------------------------------------------------------
  services.printing.enable      = true;
  hardware.bluetooth.enable     = true;
  services.avahi.enable         = true;
  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;

  # -----------------------------------------------------------
  # SAMBA
  # -----------------------------------------------------------
  services.samba = {
    enable   = true;
    settings = {
      global = {
        "workgroup"      = "WORKGROUP";
        "server string"  = "smbnix";
        "netbios name"   = "smbnix";
        "security"       = "user";
        "map to guest"   = "bad user";
        "load printers"  = "no";
      };
      public = {
        "path"            = "/home/todd/Public";
        "browseable"      = "yes";
        "read only"       = "no";
        "guest ok"        = "yes";
        "create mask"     = "0644";
        "directory mask"  = "0755";
        "force user"      = "todd";
      };
    };
  };
  services.samba-wsdd = { enable = true; openFirewall = true; };

  # -----------------------------------------------------------
  # FIREWALL — Samba + Sunshine + KDE Connect range
  # -----------------------------------------------------------
  networking.firewall = {
    enable           = true;
    allowedTCPPorts  = [ 445 139 47984 47989 47990 48010 ];
    allowedUDPPorts  = [ 137 138 ];
    allowedUDPPortRanges = [
      { from = 47998; to = 48000; }
      { from = 8000;  to = 8010;  }
    ];
  };

  # -----------------------------------------------------------
  # SUNSHINE (game stream host)
  # -----------------------------------------------------------
  security.wrappers.sunshine = {
    owner        = "root";
    group        = "root";
    capabilities = "cap_sys_admin+p";
    source       = "${pkgs.sunshine}/bin/sunshine";
  };
  hardware.uinput.enable = true;

  # -----------------------------------------------------------
  # VIRT / DEV ENABLEMENT (dev.nix adds packages; this turns daemons on)
  # -----------------------------------------------------------
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable   = true;

  # -----------------------------------------------------------
  # ADB USB rules (matches your old setup)
  # -----------------------------------------------------------
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0660", GROUP="adbusers"
    SUBSYSTEM=="usb", ATTR{idVendor}=="0bb4", MODE="0660", GROUP="adbusers"
    SUBSYSTEM=="usb", ATTR{idVendor}=="12d1", MODE="0660", GROUP="adbusers"
    SUBSYSTEM=="usb", ATTR{idVendor}=="0502", MODE="0660", GROUP="adbusers"
    SUBSYSTEM=="usb", ATTR{idVendor}=="0fce", MODE="0660", GROUP="adbusers"
    SUBSYSTEM=="usb", ATTR{idVendor}=="2a70", MODE="0660", GROUP="adbusers"
  '';

  # -----------------------------------------------------------
  # BROWSER
  # -----------------------------------------------------------
  programs.firefox.enable = true;

  # -----------------------------------------------------------
  # SYSTEM-WIDE PACKAGE BASE (DE modules layer on top)
  # -----------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # core utilities
    eza bat fd ripgrep fzf jq yq-go
    nix-output-monitor nvd
    htop btop nvtopPackages.full sysprof
    hardinfo2 lshw pciutils
    vlc mpv ffmpeg yt-dlp parabolic freetube
    fastfetch
    wget curl
    micro neovim vim
    yazi xarchiver unzip p7zip
    xclip wl-clipboard
    pika-backup
    systemd-bootchart
    wcalc bc pro-office-calculator

    # terminals (per-DE files don't need to redeclare)
    kitty foot xterm alacritty

    # GUI utilities
    meld kdiff3
    gnome-disk-utility
    keepassxc
    github-desktop
    qbittorrent
    onlyoffice-desktopeditors
    obsidian
    sunshine moonlight-qt
    discord vesktop
    rustdesk-flutter
    obs-studio tenacity gimp
    geany-with-vte
    ventoy-full-qt
    goverlay mangohud vkbasalt ydotool
    wineWowPackages.stable winetricks
    prismlauncher lutris protonplus
    jdk8 jdk17 jdk21

    # icon / theme assets shared across all DEs
    adwaita-icon-theme
    papirus-icon-theme
    tokyonight-gtk-theme
    catppuccin catppuccin-cursors
    nordzy-icon-theme nordzy-cursor-theme
    cosmic-icons xcursor-pro

    # Qt6 bits used by misc tools
    qt6.qtdeclarative qt6.qtsvg qt6.qtwayland qt6.qtbase

    # browsers (firefox is via programs.firefox, the rest are pkgs)
    brave librewolf vivaldi chromium

    # Android / JVM
    android-studio android-tools gradle
    jetbrains.idea-community-bin

    # Python with the few site packages you use regularly
    (python3.withPackages (ps: with ps; [
      tkinter
      pygame-gui
      pyside6
    ]))
  ];

  # -----------------------------------------------------------
  # SYSTEM
  # -----------------------------------------------------------
  system.stateVersion = "25.11";

  # autoUpgrade is disabled on purpose. This system is flake-driven, and the
  # channel-based upgrade path doesn't track our pinned inputs. Run:
  #   sudo ./scripts/swap.sh <de>   to upgrade in lockstep with the lockfile.
  system.autoUpgrade.enable = false;
}
