{ stdenv, ... }: let
  # Vendor ID common for both my DELL monitors
  vendorId = "0bda";

  pkgs = import <nixpkgs> {};
  script = pkgs.writeScript "usb-kvm" builtins.readFile ./usb-kvm.fish;
in {
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{ID_VENDOR_ID}=="${vendorId}", RUN+="${script}/bin/usb-kvm"
  '';
}
