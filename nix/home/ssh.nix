{ lib, ... }: {
  programs.ssh = {
    enable = true;
    includes = ["~/.ssh/config_local"];
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
