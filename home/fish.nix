{ pkgs, ... }: {
  # On first fish launch:
  # tide configure --auto --style=Classic --prompt_colors='True color' --classic_prompt_color=Dark --show_time='24-hour format' --classic_prompt_separators=Angled --powerline_prompt_heads=Sharp --powerline_prompt_tails=Slanted --powerline_prompt_style='Two lines, character and frame' --prompt_connection=Dotted --powerline_right_prompt_frame=Yes --prompt_connection_andor_frame_color=Dark --prompt_spacing=Compact --icons='Few icons' --transient=Yes
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting
      fzf_configure_bindings --directory=\ef --git_log=\eg --processes=\eq --variables=\ev
      bind \e\` "__smart_help (commandline -p)"
      # Maps to Ctrl-Shift-Delete
      bind \e\[3\;6~ __forget
      export FLAKE_URL="/home/dzervas/Lab/dotfiles?submodules=1"

      # Watch command completions
      complete -c watch -s n -l interval -d "Set update interval in seconds"
      complete -c watch -s d -l differences -d "Highlight differences between updates"
      complete -c watch -s g -l exit-diff -d "Exit when output differences occur"
      complete -c watch -s e -l exit-error -d "Exit if the command returns a non-zero exit code"
      complete -c watch -f -a "(__fish_complete_subcommand)"
    '';
    plugins = [
      { name = "autopair"; inherit (pkgs.fishPlugins.autopair) src; }
      { name = "fzf-fish"; inherit (pkgs.fishPlugins.fzf-fish) src; }
      { name = "puffer"; inherit (pkgs.fishPlugins.puffer) src; }
      { name = "tide"; inherit (pkgs.fishPlugins.tide) src; }
    ];

    functions = {
      backup = {
        body = builtins.readFile ./fish-functions/backup.fish;
        description = "Backup a file or directory";
        wraps = "cp";
      };
      crest = {
        body = builtins.readFile ./fish-functions/crest.fish;
        description = "A curl wrapper with enhanced features tailored for REST APIs";
        wraps = "curl";
      };
      kubeseal-env = {
        body = builtins.readFile ./fish-functions/kubeseal-env.fish;
        description = "Create a kubeseal secret from an env file";
      };
      mc = {
        body = "mkdir -p $argv[1] && cd $argv[1]";
        description = "Create a directory and change to it";
        wraps = "mkdir";
      };
      needs-update = {
        body = builtins.readFile ./fish-functions/needs-update.fish;
        description = "Check if a newer nixpkgs version is available";
      };
      rebuild = {
        body = builtins.readFile ./fish-functions/rebuild.fish;
        description = "Rebuild the system";
        wraps = "nixos-rebuild switch";
      };
      use = {
        body = builtins.readFile ./fish-functions/use.fish;
        description = "Use a nix shell";
        wraps = "nix shell";
      };
      watchf = {
        body = builtins.readFile ./fish-functions/watchf.fish;
        description = "Watch command";
        wraps = "nix shell";
      };

      # Internal
      __smart_help = builtins.readFile ./fish-functions/smart-help.fish;
      __forget = builtins.readFile ./fish-functions/forget.fish;
    };

    shellAliases = {
      update = "nix flake update --flake \"$FLAKE_URL\" && rebuild";
      miniterm = "python3 -m serial.tools.miniterm";
      v = "nvim";
      w = "watchf";
    };
  };
}
