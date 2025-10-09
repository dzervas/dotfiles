{ pkgs, ... }: {
  home.packages = with pkgs; [
    (proxmark3.override { withGeneric = true; }) # Proxmark3 Easy
    # Broken
    # buspirate5-firmware
    adafruit-nrfutil
    esptool
    mpremote
    circup
  ];
}
