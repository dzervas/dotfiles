{ pkgs, ... }: {
  nix = {
    package = pkgs.nix;
    extraOptions = ''
      # Garbage collect when free space is less than 32GB
      min-free = ${toString (32 * 1024 * 1024 * 1024)}
    '';
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      warn-dirty = false;
      max-jobs = "auto";
      cores = 0;  # Use all available cores
      build-cores = 0;
      http-connections = 50; # Parallel downloads
      download-buffer-size = 524288000;
      auto-optimise-store = true;

      # Keep more derivations in memory
      keep-derivations = true;
      keep-outputs = true;

      # Only allow wheel users to run nix
      trusted-users = [ "@wheel" "root" ];
    };
  };
}
