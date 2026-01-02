{ pkgs, ... }: {
  services = {
    blueman-applet.enable = true;
    network-manager-applet.enable = true;
    # pasystray.enable = true; # Broken
  };

  home.packages = with pkgs; [ pavucontrol ];
}
