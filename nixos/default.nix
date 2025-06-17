{ config, ... }: {
  imports = [
    ./1password.nix
    #./apparmor.nix
    ./bluetooth.nix
    ./cli.nix
    ./ddc-ci.nix
    ./display.nix
    ./network.nix
    ./nix.nix
    ./steam.nix
    ./theme.nix
    # ./usb-kvm.nix
    ./user.nix
    ./vim.nix
  ];

  # TODO: Mark all partitions as noexec apart from /nix/store/

  nixpkgs.config = {
    allowUnfree = true;
    segger-jlink.acceptLicense = true;
  };

  hardware.enableAllFirmware = true;

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

  services = {
    dbus.enable = true;
    fwupd.enable = true;

    # Better getty
    kmscon = {
      #enable = lib.mkDefault true;
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
      wireplumber = {
        enable = true;
        extraConfig = {
          "51-disable-hfp" = {
            "wireplumber.settings" = {
              "bluetooth.autoswitch-to-headset-profile" = false;
            };
            "monitor.bluez.properties" = {
              "bluez5.roles" = [ "a2dp_sink" "a2dp_source" ];
            };
          };
        };
      };
    };
  };
}
