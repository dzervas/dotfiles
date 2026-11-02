# Bubblewrapped packages, see overlays/mk-bwrap.nix for the semantics of each option.
# Lists merge across modules, so a machine can add its own paths to an existing sandbox.
{ config, lib, pkgs, ... }: let
  inherit (lib) mkOption types;

  mountType = types.either types.str (types.submodule {
    options = {
      path = mkOption { type = types.str; };
      try = mkOption {
        type = types.bool;
        default = false;
        description = "Skip the bind when the path is missing";
      };
    };
  });

  sandboxType = types.submodule ({ config, ... }: {
    options = {
      package = mkOption { type = types.package; };
      alias = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Install the sandbox as bin/<alias> next to the package instead of replacing it";
      };
      args = mkOption { type = types.listOf types.str; default = []; };
      home = mkOption { type = types.nullOr types.str; default = null; };
      net = mkOption { type = types.bool; default = false; };
      gpu = mkOption { type = types.bool; default = false; };
      ro = mkOption { type = types.listOf mountType; default = []; };
      rw = mkOption { type = types.listOf mountType; default = []; };
      dev = mkOption { type = types.listOf mountType; default = []; };
      env = mkOption { type = types.attrsOf types.str; default = {}; };
      keepEnv = mkOption { type = types.nullOr (types.listOf types.str); default = null; };
      unsetEnv = mkOption { type = types.listOf types.str; default = []; };
      setup = mkOption { type = types.lines; default = ""; };
      extraArgs = mkOption { type = types.listOf types.str; default = []; };

      finalPackage = mkOption {
        type = types.package;
        readOnly = true;
      };
    };

    config.finalPackage = pkgs.mkBwrap {
      inherit (config)
        package
        alias
        args
        home
        net
        gpu
        ro
        rw
        dev
        env
        keepEnv
        unsetEnv
        setup
        extraArgs
        ;
    };
  });
in {
  options.sandboxes = mkOption {
    type = types.attrsOf sandboxType;
    default = {};
  };

  config.home.packages = lib.mapAttrsToList (_: sandbox: sandbox.finalPackage) config.sandboxes;
}
