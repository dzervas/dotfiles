{ pkgs, ... }: {
  home.packages = with pkgs; [
    (proxmark3.override { withGeneric = true; }) # Proxmark3 Easy
    buspirate5-firmware
    adafruit-nrfutil
    esptool
    mpremote
    circup
  ];
}
