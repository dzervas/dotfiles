{ pkgs, ... }: {
  # On first fish launch:
  # tide configure --auto --style=Classic --prompt_colors='True color' --classic_prompt_color=Dark --show_time='24-hour format' --classic_prompt_separators=Angled --powerline_prompt_heads=Sharp --powerline_prompt_tails=Slanted --powerline_prompt_style='Two lines, character and frame' --prompt_connection=Dotted --powerline_right_prompt_frame=Yes --prompt_connection_andor_frame_color=Dark --prompt_spacing=Compact --icons='Few icons' --transient=Yes
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting
      fzf_configure_bindings --directory=\ef --git_log=\eg --processes=\eq --variables=\ev
      bind \e\` "smart-help (commandline -p)"
      export FLAKE_URL="/home/dzervas/Lab/dotfiles/nix?submodules=1"
    '';
    plugins = [
      { name = "autopair"; src = pkgs.fishPlugins.autopair.src; }
      { name = "fzf-fish"; src = pkgs.fishPlugins.fzf-fish.src; }
      { name = "puffer"; src = pkgs.fishPlugins.puffer.src; }
      { name = "tide"; src = pkgs.fishPlugins.tide.src; }
    ];

    functions = {
      backup = builtins.readFile ./fish-functions/backup.fish;
      kubeseal-env = builtins.readFile ./fish-functions/kubeseal-env.fish;
      use = builtins.readFile ./fish-functions/use.fish;
      rebuild = builtins.readFile ./fish-functions/rebuild.fish;
      smart-help = builtins.readFile ./fish-functions/smart-help.fish;
      update = builtins.readFile ./fish-functions/update.fish;

      mc = {
        description = "Create a directory and change to it";
        body = "mkdir -p $argv[1] && cd $argv[1]";
      };
    };
  };
}