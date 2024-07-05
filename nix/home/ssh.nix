{ lib, ... }: {
	programs.ssh = {
    enable = true;
    matchBlocks = {
      "github.com" = {
        user = "git";
      };

      # Aliases
      gh = {
        hostname = "github.com";
        user = "git";
      };
    };
  };
}