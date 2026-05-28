# iso-installer.nix — live-ISO config used by:
#   nix build .#nixosConfigurations.installer.config.system.build.isoImage
#
# What this ISO does on boot:
#   1. Auto-login as `nixos` on tty1
#   2. NetworkManager auto-connects to the hardcoded WiFi (HTBM-1K)
#   3. /etc/profile.d/iBP-launcher.sh prints a banner and offers to
#      launch the bootstrap wizard immediately. Press Enter to install.
#   4. bootstrap.sh detects the bundled repo at /etc/iBP-Nix-Install/repo,
#      copies it to /tmp/iBP-Nix-Install (writable), and runs install-core.
{ pkgs, lib, modulesPath, config, ... }:

let
  # Embed the whole repo into the ISO. filterSource strips .git, build
  # artifacts, and any stray `result` symlinks so we don't bake several
  # hundred MB of git history into a 4 GB ISO.
  repoSrc = builtins.filterSource
    (path: type:
      let base = baseNameOf path; in
        base != ".git"
        && base != "result"
        && base != "result-bin"
        && base != "result-lib"
        && base != ".direnv")
    ./.;
in
{
  # -----------------------------------------------------------
  # NETWORKING — hardcoded WiFi, NetworkManager auto-connects
  # -----------------------------------------------------------
  networking.networkmanager.enable = true;
  networking.wireless.iwd.enable   = true;

  # Pre-shared WPA2 profile baked into the image. NetworkManager picks
  # this up on boot and auto-connects. The PSK lives in plaintext inside
  # the ISO — acceptable for a personal install USB.
  networking.networkmanager.ensureProfiles.profiles = {
    "HTBM-1K" = {
      connection = {
        id          = "HTBM-1K";
        type        = "wifi";
        autoconnect = true;
      };
      wifi = {
        mode = "infrastructure";
        ssid = "HTBM-1K";
      };
      wifi-security = {
        key-mgmt = "wpa-psk";
        psk      = "M3owzas!";
      };
      ipv4.method = "auto";
      ipv6.method = "auto";
    };
  };

  # -----------------------------------------------------------
  # LIVE USER
  # -----------------------------------------------------------
  users.users.nixos = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" ];
  };
  security.sudo.wheelNeedsPassword = false;
  services.getty.autologinUser     = "nixos";

  # -----------------------------------------------------------
  # ISO TOOLING
  # -----------------------------------------------------------
  environment.systemPackages = lib.mkAfter (with pkgs; [
    bash coreutils util-linux
    parted gptfdisk
    networkmanager iwd
    iwgtk                          # GUI wifi picker (fallback if HTBM-1K
                                   # isn't in range — pkill nmcli; iwgtk &)
    curl wget git
    lshw pciutils
    btrfs-progs ntfs3g exfatprogs
    rsync
    zstd

    # os-prober (needs to detect Windows + CachyOS at install time)
    os-prober
    grub2
  ]);

  boot.supportedFilesystems = [ "ntfs" "exfat" ];

  # -----------------------------------------------------------
  # BUNDLE THE WHOLE REPO INTO THE ISO
  # -----------------------------------------------------------
  # /etc/iBP-Nix-Install/repo is read-only (it's an /etc symlink to the
  # nix store). bootstrap.sh detects this path and copies it to /tmp.
  environment.etc."iBP-Nix-Install/repo".source = repoSrc;

  # -----------------------------------------------------------
  # AUTO-LAUNCH THE BOOTSTRAP WIZARD ON FIRST INTERACTIVE SHELL
  # -----------------------------------------------------------
  environment.etc."profile.d/iBP-launcher.sh".text = ''
    # Runs once per interactive login on the live ISO. Use $IBP_BOOTSTRAPPED
    # so re-running `bash` in the wizard doesn't recurse.
    if [ -z "''${IBP_BOOTSTRAPPED:-}" ] && [ -t 0 ] \
        && [ "$USER" = "nixos" ] && [ -t 1 ]; then
        export IBP_BOOTSTRAPPED=1

        # Give NetworkManager a moment to associate. Most installs need
        # network access during nixos-install for the package downloads.
        echo "→ Waiting up to 15s for NetworkManager to acquire IP..."
        for i in $(seq 1 15); do
            if ${pkgs.iproute2}/bin/ip route get 1.1.1.1 >/dev/null 2>&1; then
                break
            fi
            sleep 1
        done

        cat <<'BANNER'

  ╔══════════════════════════════════════════════════════════════╗
  ║                                                              ║
  ║       iBP-Nix-Install — NixOS deployment for Todd           ║
  ║                                                              ║
  ║   Target:    /dev/nvme1n1  (PNY — second NVMe)              ║
  ║   Preserves: /dev/nvme0n1  (Windows + CachyOS, untouched)   ║
  ║   Default:   KDE Plasma 6, X11 session (best for GW2)       ║
  ║   Network:   Auto-connecting to HTBM-1K                     ║
  ║                                                              ║
  ║   Repo is bundled — no clone needed.                         ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝

BANNER
        read -r -p "  Launch the installer now? [Y/n]: " ans
        case "''${ans:-Y}" in
            [Nn]*)
                echo ""
                echo "  OK — when ready:"
                echo "    sudo bash /etc/iBP-Nix-Install/repo/scripts/bootstrap.sh"
                echo ""
                echo "  Or for a fully-automated install with all defaults:"
                echo "    sudo bash /etc/iBP-Nix-Install/repo/scripts/bootstrap.sh --auto kde"
                ;;
            *)
                exec sudo bash /etc/iBP-Nix-Install/repo/scripts/bootstrap.sh
                ;;
        esac
    fi
  '';
}
