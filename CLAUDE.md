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
- **Editor**: Neovim configured via NixVim in `home/neovim` with comprehensive LSP, AI assistance, and development tools
- **Storage**: BTRFS with compression, deduplication, snapshots
- **Security**: Secure boot (lanzaboote), LUKS encryption, AppArmor
- **Theming**: Stylix with Rose Pine theme

### Development Environment
Includes comprehensive tooling for:
- **Languages**: Nix, Python, Rust, Go, JavaScript/Node.js
- **Cloud/DevOps**: Kubernetes (kubectl, k9s, helm), Terraform, AWS CLI, Argo CD
- **Containers**: Podman, Flatpak support
- **Security**: 1Password integration via opnix

## Configuration Patterns

### Modular Design
Each directory contains a `default.nix` that imports component modules. Hardware and desktop features are broken into reusable components that can be mixed and matched per machine.

### Options System
Custom options defined in `home/options.nix` provide consistent configuration across all machines and components.

### Private Configuration Support
The system supports private configuration modules via `nix-private` input, with dummy fallback for public builds.

## NixVim Editor Configuration

The Neovim configuration is fully declarative via NixVim and split across multiple modules:

### Core Configuration (`home/neovim/default.nix`)
- **LSP Servers**: Comprehensive language server support for DevOps (Ansible, Bash, Docker, Helm, Nix, Terraform), Development (C/C++, Go, Python, Rust), and Web (Astro, CSS, HTML, TypeScript, Tailwind)
- **Completion**: blink-cmp with intelligent Tab behavior that integrates with Copilot suggestions
- **Debugging**: DAP support with Python and Rust debugging capabilities
- **Formatting/Linting**: none-ls integration with extensive formatters and linters
- **Key Features**: Tree-sitter syntax highlighting, auto-pairs, surround editing, multicursors, fuzzy finding via Telescope

### AI Assistant Integration (`home/neovim/ai.nix`)
- **GitHub Copilot**: Smart project/buffer-level enablement with custom management system
- **Avante**: AI chat interface with Claude integration for code assistance
- **Custom Keybindings**: `<leader>cc` for Copilot management, `<leader>at/aa` for Avante

### UI Enhancements (`home/neovim/ui.nix`)
- **Buffer Management**: BufferLine with diagnostics and slanted separators
- **Status Line**: Lualine with Copilot status indicator and relative file paths
- **Enhanced UI**: Noice for better command line and LSP progress, Trouble for diagnostics
- **Navigation**: Telescope with fzf, zoxide, and undo tree integration

### Rust Development (`home/neovim/rust.nix`)
- **Rustaceanvim**: Advanced Rust development with dedicated LSP target directory
- **Debugging**: LLDB integration via dap-lldb
- **Custom Formatting**: Hard tabs, 4-space width, 100-character line limit

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
