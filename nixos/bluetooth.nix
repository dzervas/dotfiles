{ config, ... }: {
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = config.networking.hostName != "laptop";
    settings = {
      General = {
        ControllerMode = "dual";
        FastConnectable = "true";
        Experimental = "true";
        # Enable = "Source,Sink,Media,Socket"; # No longer an option?
      };
      LE.EnableAdvMonInterleaveScan = "true";
    };
  };

  # To make LE Audio work:
  # https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/LE-Audio-+-LC3-support
  # https://discourse.nixos.org/t/are-ble-lc3-supported/53920
  # Make sure that `bluetoothctl info <device>` and `show` both have the following UUID exposed:
  # Published Audio Capabilities (00001850-0000-1000-8000-00805f9b34fb)
  # The active profile then needs to be bap-duplex

  boot.kernelParams = [ "btusb.enable_autosuspend=n" ];

  # Needed for home-manager's blueman
  services.blueman.enable = true;

  # Better Xbox gamepad driver
  # hardware.xpadneo.enable = true;

  # Disable bluetooth headphone HFP profile
  services.pipewire.wireplumber.extraConfig = {
    "51-disable-hfp" = {
      "wireplumber.settings" = {
        "bluetooth.autoswitch-to-headset-profile" = false;
      };
      "monitor.bluez.properties" = {
        "bluez5.roles" = [ "a2dp_sink" "a2dp_source" "bap_duplex" ];
      };
    };
  };
}
