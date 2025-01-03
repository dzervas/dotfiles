# bubblewrap wrapper that auto-generates an overlay with the bwrap command.
{ config, inputs, lib, pkgs, ... }:
let
  inherit (lib) mkOption types;

  pkgOptions = types.submodule {
    options = {
      # Custom command to run instead of discovered $out/bin/*
      customCommand = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Custom command to run if binary is not found";
      };

      # Bind mount options
      bind = mkOption {
        type = types.listOf bindTryOption;
        default = [];
        description = "List of bind mounts to pass to bwrap";
      };
      dev-bind = mkOption {
        type = types.listOf bindTryOption;
        default = [];
        description = "List of dev-bind mounts to pass to bwrap";
      };
      ro-bind = mkOption {
        type = types.listOf bindTryOption;
        default = [];
        description = "List of ro-bind mounts to pass to bwrap";
      };

      # Kernel mounts
      proc = mkOption {
        type = types.str;
        default = "/proc";
        description = "Proc option for bwrap";
      };
      dev = mkOption {
        type = types.str;
        default = "/dev";
        description = "Dev option for bwrap";
      };
      tmpfs = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List of tmpfs options for bwrap";
      };

      # Environment variables
      setenv = mkOption {
        type = types.attrsOf types.str;
        default = [];
        description = "Set an environment variable";
      };
      unsetenv = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Unset an environment variable";
      };

      # Namespace options
      die-with-parent = mkOption {
        type = types.bool;
        default = true;
        description = "Kills with SIGKILL child process (COMMAND) when bwrap or bwrap's parent dies.";
      };
      new-session = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to use new-session option";
      };
      unshare-all = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to unshare all namespaces";
      };
      share-net = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to share network namespace";
      };
    };
  };

  bindTryOption = types.submodule {
    options = {
      src = mkOption {
        type = types.str;
        description = "Source path";
      };
      dest = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Destination path";
      };
      try = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to use try option";
      };
    };
  };

  bindTryArg = prefix: opts:
    (builtins.concatMap (opt:
      let
        src = if opt.src == null then throw "src is required" else opt.src;
        dest = if opt.dest == null then src else opt.dest;
        try = opt.try or false;
      in [ "${prefix}${if try then "-try" else ""} ${src} ${dest}" ]
    ) opts);

  # Construct the bwrap command line arguments based on the options above as a list
  # Takes a single package config as argument
  buildBwrapArgs = pkgConfig:
    (if pkgConfig.new-session then [ "--new-session" ] else []) ++
    (if pkgConfig.die-with-parent then [ "--die-with-parent" ] else []) ++
    (if pkgConfig.unshare-all then [ "--unshare-all" ] else []) ++
    (if pkgConfig.share-net then [ "--share-net" ] else []) ++
    (if pkgConfig.dev != "" then [ "--dev" pkgConfig.dev ] else []) ++
    (if pkgConfig.proc != "" then [ "--proc" pkgConfig.proc ] else []) ++
    builtins.concatMap (path: [ "--tmpfs" path ]) pkgConfig.tmpfs ++
    lib.attrsets.mapAttrsToList (name: value: "--setenv ${name} ${value}") pkgConfig.setenv ++
    builtins.concatMap (value: [ "--unsetenv" value ]) pkgConfig.unsetenv ++
    bindTryArg "--dev-bind" pkgConfig.dev-bind ++
    bindTryArg "--ro-bind" pkgConfig.ro-bind ++
    bindTryArg "--bind" pkgConfig.bind;

  # Create the actual overlay
  wrapPackage = { name, package, pkgConfig }:
    (super: self: let
      pname = "${package.pname or name}";
    in {
      "${pname}" = self.stdenv.mkDerivation rec {
        inherit pname;

        src = package;
        version = package.version or "unknown";
        buildInputs = [ super.bubblewrap ];
        dontUnpack = true;
        installPhase = let
          bwrapArgs = lib.strings.concatStringsSep " " (buildBwrapArgs pkgConfig);
        in ''
          mkdir -p $out/bin
          ${if pkgConfig.customCommand != null then ''
          cat > $out/bin/${name} <<EOF
          #!${super.runtimeShell}
          exec ${super.bubblewrap}/bin/bwrap ${bwrapArgs} -- ${pkgConfig.customCommand} "\$@"
          EOF
          chmod +x $out/bin/${name}
          '' else ''
          for bin in ${src}/bin/*; do
            if [ -x "$bin" ]; then
              progName=$(basename $bin)
              cat > $out/bin/$progName <<EOF
          #!${super.runtimeShell}
          exec ${super.bubblewrap}/bin/bwrap ${bwrapArgs} -- "$bin" "\$@"
          EOF
              chmod +x $out/bin/$progName
            fi
          done
          ''}
        '';
      };
    }
  );

  # Return nixpkgs with the generated overlay
  wrapPackageOverlay = { name, package, pkgConfig }: (import inputs.nixpkgs {
    inherit (pkgs) system;

    overlays = [ (wrapPackage { inherit name package pkgConfig; }) ];
  });
in {
  # Define the bwrapper configuration
  options.bwrapper = mkOption {
    type = types.attrsOf pkgOptions;
    description = "Per-package bwrap configurations";
  };

  # Consume the bwrapper configuration, wrap the packages and install them
  config.home.packages = lib.attrValues (
    lib.mapAttrs

    # For each package in the bwrapper configuration, wrap the package and install it
    # mapAttrs function
    (name: pkgConfig: let
        package = pkgs.${name} or (throw "Package ${name} not found in pkgs");
      in
        (wrapPackageOverlay { inherit name package pkgConfig; })."${name}"
    )

    config.bwrapper
    # At this point we've constructed a map in the form of { pkgName = (overlay).pkgName }
  ); # Unfurl the map to be a list of (overlay).pkgName
}
