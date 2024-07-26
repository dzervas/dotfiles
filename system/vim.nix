{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    vim-full
  ];
  environment.etc.vimrc.source = ./vimrc;
}
