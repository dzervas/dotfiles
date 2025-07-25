{ pkgs, ... }: {
  home.shell.enableFishIntegration = true; # Enable fish integration for everything

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting
      fzf_configure_bindings --directory=\ef --git_log=\eg --processes=\eq --variables=\ev
      bind \ew "echo; watchf (commandline); echo; echo; commandline -f repaint"
      bind \e\` "__smart_help (commandline -p)"
      # Maps to Ctrl-Shift-Delete
      bind \e\[3\;6~ __forget
      export FLAKE_URL="/home/dzervas/Lab/dotfiles?submodules=1&lfs=1"

      # Watch command completions
      complete -c watchf -s n -l interval -d "Set update interval in seconds"
      complete -c watchf -s d -l differences -d "Highlight differences between updates"
      complete -c watchf -s g -l exit-diff -d "Exit when output differences occur"
      complete -c watchf -s e -l exit-error -d "Exit if the command returns a non-zero exit code"
      complete -c watchf -f -a "(__fish_complete_subcommand)"
    '';
    plugins = [
      { name = "autopair"; inherit (pkgs.fishPlugins.autopair) src; }
      { name = "fzf-fish"; inherit (pkgs.fishPlugins.fzf-fish) src; }
      { name = "puffer"; inherit (pkgs.fishPlugins.puffer) src; }
    ];

    # TODO: Add a flake-init function that generates a flake shell with whatever is in the env from use and checks for common lang files
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
      kubelog = {
        body = builtins.readFile ./fish-functions/kubelog.fish;
        description = "KubeCTL log for human beings";
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
      scanner = {
        description = "Ask for a scan from the local scanner";
        body = ''
          set -l filename (string split $argv[1])
          ${pkgs.sane-backends}/bin/scanimage -p --mode Color --resolution 600 --format=$filename[-1] -o $argv[1]
        '';
        wraps = "scanimage";
      };
      scanner-many = {
        description = "Ask for multiple scans from the local scanner and merge them into a pdf";
        body = ''
          set -l count (string split $argv[1])
          set -l filename (string split $argv[2])
          ${pkgs.sane-backends}/bin/scanimage -p --mode Color --resolution 600 --format=tiff --batch=/tmp/scanner-many.p%04.tiff --batch-prompt --batch-count $count
          echo
          echo
          echo Scan done, compressing images into a pdf (might take a minute)
          ${pkgs.imagemagick}/bin/magick -density 120 -quality 40 -compress jpeg /tmp/scanner-many.p*.tiff $filename
        '';
        wraps = "scanimage";
      };
      todo = {
        body = builtins.readFile ./fish-functions/todo.fish;
        description = "Find local todos";
      };
      use = {
        body = builtins.readFile ./fish-functions/use.fish;
        description = "Use a nix shell";
        wraps = "nix shell";
      };
      watchf = {
        body = builtins.readFile ./fish-functions/watchf.fish;
        description = "Watch command";
        # wraps = "nix shell";
      };

      # Internal
      __smart_help = builtins.readFile ./fish-functions/smart-help.fish;
      __forget = builtins.readFile ./fish-functions/forget.fish;
    };

    shellAliases = {
      update = "sh (echo -n $FLAKE_URL | cut -d'?' -f1)/.github/scripts/gha-updater.sh && nix flake update --flake \"$FLAKE_URL\" && rebuild";
      miniterm = "python3 -m serial.tools.miniterm";
      kl = "kubelog";
      v = "nvim";
      w = "watchf";
    };
  };
}
