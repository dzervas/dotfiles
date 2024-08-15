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

      "*.dzerv.art" = { user = "root"; };
    };
  };
}
