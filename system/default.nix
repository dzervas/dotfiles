{ ... }: {
  nixpkgs.config.allowUnfree = true;

  imports = [
    ./1password.nix
    ./bluetooth.nix
    ./cli.nix
    ./display.nix
    ./fonts.nix
    ./network.nix
    ./theme.nix
    # ./usb-kvm.nix
    ./vim.nix
  ];

  services.dbus.enable = true;
}
