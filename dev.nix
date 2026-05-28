# dev.nix — software development suite
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # ── C / C++ toolchain ───────────────────────────────────────────
    gcc
    clang
    clang-tools           # clangd + clang-format
    gnumake
    cmake
    ninja
    pkg-config
    gdb
    lldb
    valgrind
    bear                  # generates compile_commands.json

    # ── Windows cross-compile (GW2 Nexus addons) ────────────────────
    # Provides x86_64-w64-mingw32-g++ used by your toolchain-mingw.cmake
    pkgsCross.mingwW64.buildPackages.gcc
    pkgsCross.mingwW64.buildPackages.binutils

    # ── Rust ────────────────────────────────────────────────────────
    rustup
    rust-analyzer

    # ── Node / web ──────────────────────────────────────────────────
    nodejs_22
    nodePackages.pnpm
    nodePackages.typescript-language-server

    # ── Go ──────────────────────────────────────────────────────────
    go
    gopls

    # ── Python dev tooling (interpreter+libs are in configuration.nix) ─
    pyright
    ruff
    uv

    # ── Nix tooling ─────────────────────────────────────────────────
    nil                   # Nix LSP
    nixfmt-rfc-style
    statix
    deadnix
    nix-tree

    # ── Search / FS / shell ─────────────────────────────────────────
    tokei
    hyperfine
    sd
    just

    # ── Git tooling ─────────────────────────────────────────────────
    gh                    # GitHub CLI — used for releases
    git-lfs
    lazygit
    delta                 # prettier git diffs
    pre-commit

    # ── Editors ─────────────────────────────────────────────────────
    helix
    vscode-fhs            # Microsoft-official VS Code (FHS-wrapped for
                          # extension compatibility with .so deps).
                          # `vscodium` would be the de-Microsoft fork; we
                          # deliberately omit it — user wants the official.

    # ── AI / LLM tooling ────────────────────────────────────────────
    claude-code           # Anthropic's official CLI
    ollama                # local model runner
    # llama-cpp           # uncomment when you want raw inference

    # ── Containers / virt (libvirtd is enabled in configuration.nix) ─
    qemu_kvm
    looking-glass-client
    virtio-win
    swtpm

    # ── Misc dev utilities ──────────────────────────────────────────
    hexyl
    file
    tree
    binwalk
  ];

  # direnv with nix-direnv: `cd` into a project with `.envrc` → autoshell
  programs.direnv = {
    enable          = true;
    nix-direnv.enable = true;
    silent          = true;
  };

  # Make ADB usable without sudo (groups were added in configuration.nix)
  programs.adb.enable = true;
}
