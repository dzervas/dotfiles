{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    sway
    swaybg
    swayidle
    swaylock
    i3status
    dmenu
    rofi
    waybar
    alacritty
    thunar
    firefox
    networkmanager
    blueman
    pavucontrol
    grim
    slurp
    mako
    wl-clipboard
    brightnessctl
    playerctl
  ];

  services = {
    xserver = {
      enable = true;
      layout = "us";
      xkbOptions = "eurosign:e";
    };

    sway = {
      enable = true;
      user = "your-username";
      configFile = /home/your-username/.config/sway/config;
    };
  };

  users.users.your-username = {
    packages = with pkgs; [
      sway
      swaybg
      swayidle
      swaylock
      i3status
      dmenu
      rofi
      waybar
      alacritty
      thunar
      firefox
      networkmanager
      blueman
      pavucontrol
      grim
      slurp
      mako
      wl-clipboard
      brightnessctl
      playerctl
    ];
  };
}
