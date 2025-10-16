{ config, pkgs, ... }: {
  imports = [
    ./1password.nix
    ./apparmor.nix
    ./bluetooth.nix
    ./cli.nix
    ./ddc-ci.nix
    ./display.nix
    ./network.nix
    ./nix.nix
    ./stylix.nix
    # ./usb-kvm.nix
    ./user.nix
    ./vim.nix
    ./yubikey.nix
  ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # TODO: Mark all partitions as noexec apart from /nix/store/
  hardware = {
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
  };

  # Flake is used, it's irrelevant - copies the configuration.nix in /etc
  system.copySystemConfiguration = false;

  # Remove some default packages that come with nix
  environment.defaultPackages = [];

  programs = {
    dconf.enable = true;
    nix-ld = {
      enable = true;
      # libraries = with pkgs; [];
    };
  };

  fonts.packages = with pkgs; [
    iosevka-bin
    nerd-fonts.iosevka
  ];

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 10d";
    };
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };


  services = {
    dbus.enable = true;
    fwupd.enable = true;
    pcscd.enable = true;

    # Better getty
    kmscon = {
      # enable = true;
      fonts = [ config.stylix.fonts.monospace ];
      useXkbConfig = true;
      hwRender = true;
      extraConfig = ''
        xkb-layout=us,gr
        xkb-options=grp:alt_space_toggle,caps:escape
      '';
    };

    pipewire = {
      enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
  };
}
