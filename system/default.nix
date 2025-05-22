_: {
  nixpkgs.config = {
    # allowBroken = true;
    allowUnfree = true;
    segger-jlink.acceptLicense = true;
  };

  imports = [
    ./1password.nix
    #./apparmor.nix
    ./bluetooth.nix
    ./cli.nix
    ./ddc-ci.nix
    ./display.nix
    ./network.nix
    ./steam.nix
    ./theme.nix
    # ./usb-kvm.nix
    ./vim.nix
  ];

  services.dbus.enable = true;
}
