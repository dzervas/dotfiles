_: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    stdlib = builtins.readFile ./direnvrc;
    config = {
      global = {
        strict_env = true; # set -euo pipefail
        warn_timeout = "30s";
      };
    };
  };
}
