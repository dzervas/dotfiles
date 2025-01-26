_: {
  nixpkgs.config = {
    # allowBroken = true;
    allowUnfree = true;
    segger-jlink.acceptLicense = true;
  };

  imports = [
    ./1password.nix
    ./bluetooth.nix
    ./cli.nix
    ./ddc-ci.nix
    ./display.nix
    ./fonts.nix
    ./network.nix
    ./steam.nix
    ./theme.nix
    # ./usb-kvm.nix
    ./vim.nix
  ];

  services = {
    dbus.enable = true;
    ollama = {
      enable = true;
      acceleration = "rocm";
      rocmOverrideGfx = "10.1.0"; # For gfx1010, 5700XT GPU - taken from https://github.com/ollama/ollama/issues/2503#issuecomment-2487697119
    };

    open-webui = {
      enable = true;
      port = 11111;
      environment = {
        WEBUI_AUTH = "False";
      };
    };
  };
}
