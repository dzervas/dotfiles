{ config, pkgs, ... }:

{
  imports = [
    ./groups/dev.nix
    ./groups/dotfiles.nix
    ./groups/tools.nix
    ./groups/desktop-sway.nix
    ./groups/apps.nix
    ./system/boot.nix
  ];

  users.users.dzervas = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
  };

  users.groups.dev = {};
  users.groups.dotfiles = {};
  users.groups.tools = {};
  users.groups.apps = {};

  # Set fish as the default shell
  programs.fish.enable = true;

  # Clone dotfiles and create symlinks
  system.activationScripts.dotfiles = {
    text = ''
      if [ ! -d /home/dzervas/dotfiles ]; then
        git clone https://github.com/dzervas/dotfiles /home/dzervas/dotfiles
      fi
      ln -sf /home/dzervas/dotfiles/.vimrc /home/dzervas/.vimrc
      ln -sf /home/dzervas/dotfiles/.config/nvim /home/dzervas/.config/nvim
      ln -sf /home/dzervas/dotfiles/.config/alacritty /home/dzervas/.config/alacritty
      ln -sf /home/dzervas/dotfiles/.config/fish /home/dzervas/.config/fish
      # Add more symlinks as needed
    '';
  };

  # Additional configurations
  networking.firewall.allowedTCPPorts = [ 8181 ];
  networking.firewall.enable = true;

  time.timeZone = "Europe/Athens";

  # Include machine-specific configuration
  imports = [
    ./hardware/${config.networking.hostName}.nix
  ];
}
