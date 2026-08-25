# CLAUDE.md

NixOS dotfiles with Flakes. Supports 3 machines: desktop, laptop, iso.

## Quick Commands

```bash
# Build & deploy
nixos-rebuild switch --flake .#desktop   # or laptop, iso

# Lint (runs in pre-commit hook)
statix check

# Flake apps
nix run .#nvim      # Standalone neovim
nix run .#update    # Update flake + pinned overlays
nix build .#iso     # Build live ISO
```

## Structure

```
flake.nix          # Entry point, machine definitions
mkMachine.nix      # Factory: combines nixos/ + hardware/ + desktop/ + home/
nixos/             # System config (networking, display, services, security)
home/              # User config via home-manager
  options.nix      # Custom options: setup.{terminal,browser,locker,runner,windowManager,isLaptop}
  neovim/          # Modular nixvim config (also exposed as standalone app)
  fish-functions/  # Custom fish functions (rebuild, update, cop, use, etc.)
  zed/             # Symlinked to ~/Lab/dotfiles/home/zed/ (not copied)
hardware/          # Per-machine: desktop.nix, laptop.nix, iso.nix
  components/      # Reusable: amd, secure-boot, fingerprint, steam, laptop, restic
desktop/           # DE configs: hyprland (primary), kde, sway, cosmic
  home/components/ # waybar, rofi, hyprlock, hypridle, swaync
overlays/          # Custom packages + pinned versions
```

## Machines

| Machine | State | Key Features                                      |
| ------- | ----- | ------------------------------------------------- |
| desktop | 24.11 | AMD GPU, BTRFS RAID1, LUKS, beesd dedup, Steam    |
| laptop  | 25.05 | Framework 13 AMD, fingerprint, power mgmt         |
| iso     | 25.05 | Live installer, always public (no private config) |

## Key Patterns

**Module flow:** `flake.nix` → `mkMachine.nix` → imports `nixos/` + `hardware/${host}.nix` + `desktop/${de}.nix` + home-manager with `home/`

**Private config:** `nix-private` input with dummy fallback at `.github/dummy/`. Pass `isPrivate = true` in mkMachine to enable.

**Overlay updates:** Mark pinnable packages with `# nix-update:` comment. The `update` app/fish-function updates these automatically.

**Options system:** `home/options.nix` defines `setup.*` options used across desktop configs:

- `terminal`, `browser`, `runner` (program paths)
- `locker`, `lockerInstant` (screen lock commands)
- `windowManager` (hyprland/sway/kde/cosmic)
- `isLaptop` (boolean)

## Key Fish Functions

Located in `home/fish-functions/`:

- `rebuild` - Rebuild NixOS
- `update` - Full update: overlays + flake + rebuild
- `use` - Quick `nix shell` wrapper
- `cop` - GitHub Copilot CLI helper
- `committer` - AI-assisted git commit
- `mc` - mkdir + cd
- `crest` - curl wrapper for REST APIs

## Development Notes

- Prefer Fish over Bash for scripts
- Zed config is symlinked from repo, not copied
- Neovim config in `home/neovim/` is modular and also builds standalone via `nix run .#nvim`
- Pre-commit runs `statix check`
- Theming via Stylix (Rose Pine)
