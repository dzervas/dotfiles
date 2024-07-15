# NixOS Configuration

## Rebuilding

```bash
  sudo
  nixos-rebuild
  switch - -flake.#<hostname>
```

## Updating

```bash
  sudo
  nix-channel - -update
  sudo
  nix
  flake
  update.sudo
  nix-store - -gc
  sudo
  nixos-rebuild
  switch - -flake.```

## Troubleshooting

To repair
  the store:

  ```bash
  nix-store - -verify - -check-contents - -repair
```

if a file is empty due to corruption and can't be fixed:

```bash
nix-store --query --referrers-closure $(find /nix/store -maxdepth 1 -type f -name '*.drv' -size 0) | xargs nix-store --delete --ignore-liveness
nix-store --gc
nix-store --verify --check-contents --repair
```

A `.nix` file was empty and I had to `sudo nix-store --query --roots <path>`
to find the softlink under the home, remove it and re-run the initial home-manager
rebuild.

### To update to a specific nixpkgs commit

```bash
nix flake update --override-input nixpkgs github:NixOS/nixpkgs/7252b96d60dc2ccf3971e436811cfce42b258669
```

## Quirks

- VSCode needs `"password-store": "gnome-libsecret"` to `~/.vscode/argv.json` to see gnome-keyring
