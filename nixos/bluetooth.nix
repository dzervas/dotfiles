{ config, ... }: {
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = config.networking.hostName != "laptop";
    settings = {
      General = {
        ControllerMode = "dual";
        # ControllerMode = "le";
        FastConnectable = "true";
        # Experimental = "true";

        # https://github.com/bluez/bluez/blob/master/src/main.conf#L133-L144
        # KernelExperimental = "6fbaf188-05e0-496a-9885-d6ddfdb4e03e"; # ISO socket, for LE Audio
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

  # Better Xbox gamepad driver
  # hardware.xpadneo.enable = true;

  # Disable bluetooth headphone HFP profile
  services.pipewire.wireplumber.extraConfig = {
    "51-disable-hfp" = {
      "wireplumber.settings" = {
        "bluetooth.autoswitch-to-headset-profile" = false;
      };
      "monitor.bluez.properties" = {
        "bluez5.roles" = [ "a2dp_sink" "a2dp_source" "bap_duplex" "bap_source" "bap_sink" ];
      };
    };
  };
}
