{ pkgs, ... }: {
  programs.fish = {
    enable = true;
    shellAliases = {
      diff = "diff --color=always";
      man = "LC_ALL=C LANG=C man";
      pgrep = "pgrep -af";
      watch = "watch -c";
    };

    plugins = with pkgs.fishPlugins; [
      tide
      fzf-fish
      puffer
      autopair
    ];
  }
}
