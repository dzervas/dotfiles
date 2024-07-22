{ pkgs, ... }: {
  services.blueman-applet.enable = true;
  services.network-manager-applet.enable = true;

  services.pasystray.enable = true;
  home.packages = with pkgs; [ pavucontrol ];
}
