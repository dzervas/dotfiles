_: {
  programs.ssh = {
    enable = true;
    includes = ["~/.ssh/local.ssh.cfg"];
    matchBlocks = rec {
      # Aliases
      gh = {
        hostname = "github.com";
        user = "git";
      };
      github = gh;
      "github.com" = gh;

      raspberrypi = {
        hostname = "raspberrypi.local";
        user = "pi";
      };

      "*.dzerv.art" = {
        user = "root";
        # extraOptions.Tag = "sessioned";
      };

      # NOTE: To force order use lib.hm.dag.entryBefore ["entry"] { newstuff }
    };
    # TODO: Finish this
    extraConfig = ''
    Match tagged sessioned exec "ps --pid %%self -o ppid --no-headers | xargs -r ps ww --pid | grep -q '%n$'"
      RequestTTY yes
      SendEnv SESSIONED_SHELL
      RemoteCommand hash tmux 2>/dev/null && exec tmux new-session -As dzervas \; send-keys 'sudo -i' C-m || hash screen 2>/dev/null && TERM=vt100 exec screen -adRRS dzervas sudo -i || exec sudo -i
    '';
  };
}
