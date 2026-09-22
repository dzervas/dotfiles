---
name: nix-style
description: Nix coding style. Use when writing, editing, or reviewing any .nix file - NixOS modules, home-manager configs, a flake, or overlays.
---

# Nix style for this repo

Match the existing modules, not generic Nix. The rules below are the repo's
conventions; each cites a file that already follows it - read that file before
writing the same shape.

## Process

1. **Locate the layer.** Decide which directory owns the change before writing
   anything (see *Layering* below). A change in the wrong layer is the most
   common mistake.
2. **Read a sibling.** Open the file in the same directory that covers the same
   concern and copy its shape: the same arg destructuring, the same option
   paths, the same list/comment style. The sibling is the source of truth.
3. **Write the smallest change** in that shape.
4. **Verify.** Run `statix check` (the pre-commit linter)

## Layering - where a change goes

One file per concern, split by ownership:

| Concern | Location | Example |
| --- | --- | --- |
| System (root, daemons, kernel, networking, security) | `nixos/<concern>.nix` | `nixos/network.nix`, `nixos/display.nix` |
| Per-user apps & programs (home-manager) | `home/<app>.nix` | `home/git.nix`, `home/fish.nix` |
| DE / window-manager specific | `desktop/<de>.nix` + `desktop/home/components/` | `desktop/niri.nix`, `desktop/home/components/waybar.nix` |
| Per-machine hardware | `hardware/<machine>.nix` + `hardware/components/` | `hardware/desktop.nix`, `hardware/components/amd.nix` |
| New or pinned packages | `overlays/<pkg>.nix` (wired in `overlays/default.nix`) | `overlays/codex.nix` |
| Machine wiring, flake inputs, apps, substituters | `flake.nix`, `mkMachine.nix` | `flake.nix` |

Decision rule: needs root / a daemon / the kernel → `nixos/`; per-user →
`home/`; depends on which DE → `desktop/`; depends on which machine →
`hardware/`; a package that isn't in nixpkgs or needs pinning → `overlays/`.
Reusable pieces live in a `components/` subdirectory, not inline.

## Module shape

- Destructure only the args you use, always ending in `...`:
  `{ pkgs, ... }:` or `{ config, lib, pkgs, ... }:`. One arg per line when there
  are several (`home/ai.nix`).
- Return a single top-level attribute set.
- Bind locals with `let ... in { ... }`; pull values in with `inherit`:
  `inherit (lib) mkIf optionals;`, `inherit (pkgs.fishPlugins.autopair) src;`
  (`desktop/home/components/waybar.nix`, `home/fish.nix`).
- Use `rec` for a self-referential attrset (`home/ai.nix` `piSettings`).
- Prefer a **dotted path** for a single leaf (`networking.networkmanager.enable
  = true;`, `systemd.sleep.settings.Sleep = { ... }`) and a nested block only
  when several siblings share the root (`networking = { ... }`).
- `default.nix` in each directory aggregates via `imports = [ ./a.nix ./b.nix ];`
  (`home/neovim/default.nix`).

## Packages

- Package lists use the `with pkgs; [ ... ]` idiom, one item per line.
- `home.packages` for per-user, `environment.systemPackages` for system
  (`home/git.nix` vs `nixos/network.nix`).
- Group items with blank lines and a section comment: `# Python`, `# Rust`,
  `# Cloud stuff` (`home/dev.nix`).
- Sub-scopes stay scoped: `with pkgs.rocmPackages; [ ... ]`,
  `python3.withPackages (p: with p; [ ... ])` (`hardware/components/amd.nix`,
  `home/dev.nix`).

## Conditionals & precedence

- `lib.mkIf (cond) value` for a conditional value; `lib.optionals (cond) [ ... ]`
  for conditional list elements; `lib.mkDefault` / `lib.mkAfter` for precedence
  (`desktop/home/components/waybar.nix`).
- Merge attrsets with `//` (`{ ... } // niriColumnSettings`).
- Cross-DE behaviour reads the `setup.*` options namespace - `cfg.windowManager
  == "hyprland"`, `cfg.isLaptop` - defined in `home/options.nix`. Reach for a
  `setup` option before hard-coding `hostName`; reserve `hostName == "desktop"`
  for genuinely machine-specific values (e.g. the per-machine WireGuard IP in
  `nixos/network.nix`).
- Symlinks: `config.lib.file.mkOutOfStoreSymlink <path>` (`home/ai.nix`).

## Strings & embedded scripts

- Multi-line shell / fish / python goes in indented `''...''` literals.
- Reference binaries by absolute path inside strings - `${pkgs.jq}/bin/jq`,
  `${pkgs.niri}/bin/niri` - never rely on `PATH` (`desktop/home/components/waybar.nix`).
- Pull an external script file in with `builtins.readFile ./x.fish`
  (`home/fish.nix` `functions`); pull a data file the same way
  (`builtins.readFile ./waybar.style.css`).
- Generate a script as a package with `pkgs.writeShellScript` /
  `pkgs.writeShellApplication` (`home/ai.nix`, `waybar.nix`).
- Interpolate a Nix list into shell with `${lib.escapeShellArgs <list>}`
  (`home/ai.nix`).

## Overlays & version pinning

- The overlay is `final: prev: { ... }` (`overlays/default.nix`).
- New package: `prev.callPackage ./<file>.nix { }`.
- Pin or patch an existing one with
  `prev.<pkg>.overrideAttrs (finalAttrs: _oldAttrs: { version = "..."; src =
  final.fetchurl { ... }; })` - name the unused arg `_oldAttrs`, and use
  `final.fetchurl` / `final.fetchFromGitHub` inside (`overlays/default.nix`).
- Mark every pinnable package with a `# nix-update:` comment so the `update`
  app can bump it, with flags where needed: `# nix-update:codex-latest
  --custom-dep platformSrc`, `# nix-update:cursortab-nvim --subpackage server`
  (`overlays/default.nix`).
- A from-scratch package is `stdenvNoCC.mkDerivation rec { pname, version, src,
  nativeBuildInputs, installPhase, meta }`, with
  `meta = with lib; { description, homepage, license, mainProgram, platforms }`
  (`overlays/codex.nix`).

## Comments

- Comment the *why*, not the *what*.
- A short inline note after a value reads naturally:
  `accounts-daemon.enable = true; # Flatpak needs this` (`nixos/display.nix`).
- Use `# TODO:` for known gaps and `# Section` headers to group long blocks
  (`home/git.nix`, `home/neovim/default.nix`).

## Formatting

- 2-space indent; `key = value;` with a semicolon on every value except the last
  in a set.
- One list item per line, closing `]` on its own line.
- Blank line between logical groups inside a block.

## Verify

- `statix check` - the linter the pre-commit hook runs.
- For an overlay package in isolation:
  `nix build --impure --expr 'let pkgs = import <nixpkgs> {}; in pkgs.callPackage overlays/<file>.nix {}'`
  (the recipe at the top of `overlays/default.nix`).
