_: {
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true;
  };

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
        "bluez5.roles" = [ "a2dp_sink" "a2dp_source" ];
      };
    };
  };
}
