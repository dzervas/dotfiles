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
      use = {
        body = builtins.readFile ./fish-functions/use.fish;
        description = "Use a nix shell";
        wraps = "nix shell";
      };

      # Internal
      __smart_help = builtins.readFile ./fish-functions/smart-help.fish;
      __forget = builtins.readFile ./fish-functions/forget.fish;
    };

    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake \"$FLAKE_URL\"";
      update = "sudo nix-channel --update && nix flake update \"$FLAKE_URL\" && rebuild";
      v = "nvim";
    };
  };
}
