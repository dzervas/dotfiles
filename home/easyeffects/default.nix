{ config, ... }: let
  baseDir = "${config.xdg.dataHome}/easyeffects";
  mkPreset = { name, source, devices ? [], isInput ? true }: let
    dir = if isInput then "input" else "output";
  in {
    home.file = {
      "${baseDir}/${dir}/${name}.json".source = source;
    } // builtins.foldl' (
      prev: device: prev // {
        "${baseDir}/autoload/${dir}/${device}.json".text = builtins.toJSON {
          inherit device;
          device-description = name;
          device-profile = "";
          preset-name = name;
        };
    }) {} devices;
  };
in {
  services.easyeffects = {
    # enable = true;
    # preset = "default";
  };

  # imports = [
  #   (mkPreset {
  #     name = "rode_nt-usb";
  #     source = ./rode_nt-usb.json;
  #     devices = [ "alsa_input.usb-R__DE_Microphones_R__DE_NT-USB_Mini_F07D4F7D-00.mono-fallback" ];
  #   })
  # ];
}
