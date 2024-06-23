# NixOS Configuration

## Rebuilding

```bash
sudo nixos-rebuild switch --flake <nixos>#<hostname>
# First build
nix run home-manager -- switch --flake <home>
# Normal rebuild
home-manager switch --flake <home>
```

## Updating

```bash
sudo nix flake update <nixos>
sudo nix-store --gc

nix flake update <home>
nix-store --gc
```

## Troubleshooting

To repair the store:

```bash
nix-store --verify --check-contents --repair
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
