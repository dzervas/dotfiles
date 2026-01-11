# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a comprehensive NixOS dotfiles configuration using Nix Flakes. The system supports multiple machines (desktop, laptop, ISO) with modular, declarative configurations for everything from hardware to user applications.

## Key Commands

### System Management

- `statix check` - Lint Nix code (runs in pre-commit hook)

## Architecture

### Core Structure

- **`flake.nix`** - Main entry point defining system configurations and apps
- **`mkMachine.nix`** - Factory function for creating system configurations
- **`nixos/`** - System-level configurations (networking, display, services)
- **`home/`** - User-space configurations managed by home-manager
- **`hardware/`** - Modular hardware support (AMD, secure boot, Steam, etc.)
- **`desktop/`** - Desktop environment configurations (Hyprland primary, KDE/Sway/Cosmic supported)
- **`overlays/`** - Custom package overlays

### Machine Types

- **desktop** - AMD-based system with BTRFS RAID1, LUKS encryption, secure boot
- **laptop** - Framework 13 with fingerprint reader, power management
- **iso** - Live ISO with full configuration for installation/recovery

### Key Technologies

- **Primary DE**: Hyprland (Wayland compositor) with Waybar, rofi, swaylock
- **Shell**: Fish with custom functions in `home/fish-functions/`
- **Editor**: Zed editor with its config being softlinked to `home/zed/settings.json`
- **Storage**: BTRFS with compression, deduplication, snapshots
- **Security**: Secure boot (lanzaboote), LUKS encryption, AppArmor
- **Theming**: Stylix with Rose Pine theme

## Configuration Patterns

### Modular Design

Each directory contains a `default.nix` that imports component modules. Hardware and desktop features are broken into reusable components that can be mixed and matched per machine.

### Options System

Custom options defined in `home/options.nix` provide consistent configuration across all machines and components.

### Private Configuration Support

The system supports private configuration modules via `nix-private` input, with dummy fallback for public builds.

## Development Guidelines

### Shell Scripting

Prefer Fish shell for interactive scripts over Bash. Custom Fish functions are located in `home/fish-functions/` and provide better integration with the NixOS environment.

### Neovim Development

- Configuration is split across modular files in `home/neovim/`
- Custom Copilot management system provides project-specific AI assistance control
- LSP and formatting tools are extensively configured for consistent code quality
- Rust development includes specialized tooling with separate build targets for LSP performance

### Pre-commit Hooks

The repository includes statix linting that runs automatically on commits. The hook is documented in the README and checks all Nix code for quality issues.

## Updating This File

When adding significant new functionality, architectural changes, or commonly-used commands to the repository, consider updating this CLAUDE.md file to help future Claude instances work more effectively with the codebase.
