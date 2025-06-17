_: {
  nix = {
    extraOptions = ''
      # Garbage collect when free space is less than 32GB
      min-free = ${toString (32 * 1024 * 1024 * 1024)}
    '';
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 10d";
    };
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      warn-dirty = false;
      keep-outputs = true;
      max-jobs = "auto";
      cores = 0;  # Use all available cores
      build-cores = 0;

      # Only allow wheel users to run nix
      allowed-users = [ "@wheel" ];
    };
  };
}
