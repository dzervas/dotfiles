{ pkgs, ... }: {
  services = {
    # YubiKey support
    udev.packages = [ pkgs.yubikey-personalization pkgs.libu2f-host ];

    # Disable Gnome Keyring for SSH keys,
    # conflicts with the home-manager ssh-agent service
    gnome.gcr-ssh-agent.enable = false;
  };

  # programs.ssh = {
  #   startAgent = true;
  #   askPassword = "${pkgs.lxqt.lxqt-openssh-askpass}/bin/lxqt-openssh-askpass";
  #   enableAskPassword = true;
  # };
}
