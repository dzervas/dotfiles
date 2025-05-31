_: {
  services.fprintd.enable = true;
  security.pam.services = {
    sddm.fprintAuth = true;
    hyprlock.fprintAuth = true;
  };
}
