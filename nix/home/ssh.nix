{ ... }: {
	programs.ssh = {
    enable = true;
    matchBlocks = {
      "github.com" = {
        user = "git";
      };
      "gh" = {
        hostname = "github.com";
        user = "git";
      };
    };
  };
}