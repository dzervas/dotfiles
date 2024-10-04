{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption types;

  buildBwrapArgs = pkgConfig: with pkgConfig;
    let
      bindArgs = builtins.concatMap (mount:
        [ "--bind${if mount.try or false then "-try" else ""}" mount.src mount.dest ]
      ) bind;
      devBindArgs = builtins.concatMap (mount:
        [ "--dev-bind${if mount.try or false then "-try" else ""}" mount.src mount.dest ]
      ) dev-bind;
      roBindArgs = builtins.concatMap (mount:
        [ "--ro-bind${if mount.try or false then "-try" else ""}" mount.src mount.dest ]
      ) ro-bind;
      tmpfsArgs = builtins.concatMap (path: [ "--tmpfs" path ]) tmpfs;
      setenvArgs = lib.attrsets.mapAttrsToList (name: value: "--setenv ${name} ${value}") setenv;
      unsetenvArgs = builtins.concatMap (value: [ "--unsetenv" value ]) unsetenv;
      procArg = if proc != "" then [ "--proc" proc ] else [];
      devArg = if dev != "" then [ "--dev" dev ] else [];
      newSessionArg = if new-session then [ "--new-session" ] else [];
      dieWithParentArg = if die-with-parent then [ "--die-with-parent" ] else [];
      unshareAllArg = if unshare-all then [ "--unshare-all" ] else [];
      shareNetArg = if share-net then [ "--share-net" ] else [];
    in
      newSessionArg ++ unshareAllArg ++ shareNetArg ++ dieWithParentArg ++ devArg ++ procArg ++ tmpfsArgs ++ setenvArgs ++ unsetenvArgs ++ devBindArgs ++ roBindArgs ++ bindArgs;

  wrapPackage = { name, package, pkgConfig }:
    pkgs.stdenv.mkDerivation {
      pname = "${name}-bwrapped";
      version = package.version or "unknown";
      buildInputs = [ pkgs.bubblewrap ];
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out/bin
        ${if pkgConfig.customCommand != null then ''
        cat > $out/bin/${name} <<EOF
        #!${pkgs.runtimeShell}
        exec ${pkgs.bubblewrap}/bin/bwrap ${lib.strings.concatStringsSep " " (buildBwrapArgs pkgConfig)} -- ${pkgConfig.customCommand} "\$@"
        EOF
        chmod +x $out/bin/${name}
        '' else ''
        for bin in ${package}/bin/*; do
          if [ -x "$bin" ]; then
            progName=$(basename $bin)
            cat > $out/bin/$progName <<EOF
        #!${pkgs.runtimeShell}
        exec ${pkgs.bubblewrap}/bin/bwrap ${lib.strings.concatStringsSep " " (buildBwrapArgs pkgConfig)} -- "$bin" "\$@"
        EOF
            chmod +x $out/bin/$progName
          fi
        done
        ''}
      '';
    };

in {
  options.bwrapper = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        bind = mkOption {
          type = types.listOf (types.attrsOf types.anything);
          default = [];
          description = "List of bind mounts to pass to bwrap";
        };
        die-with-parent = mkOption {
          type = types.bool;
          default = true;
          description = "Kills with SIGKILL child process (COMMAND) when bwrap or bwrap's parent dies.";
        };
        dev-bind = mkOption {
          type = types.listOf (types.attrsOf types.anything);
          default = [];
          description = "List of dev-bind mounts to pass to bwrap";
        };
        ro-bind = mkOption {
          type = types.listOf (types.attrsOf types.anything);
          default = [];
          description = "List of ro-bind mounts to pass to bwrap";
        };
        proc = mkOption {
          type = types.str;
          default = "";
          description = "Proc option for bwrap";
        };
        dev = mkOption {
          type = types.str;
          default = "";
          description = "Dev option for bwrap";
        };
        tmpfs = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "List of tmpfs options for bwrap";
        };
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
        customCommand = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Custom command to run if binary is not found";
        };
      };
    });
    description = "Per-package bwrap configurations";
  };

  # config.bwrapper.wrappers = lib.attrValues (lib.mapAttrs (pkgName: pkgConfig:
  config.home.packages = lib.attrValues (lib.mapAttrs (pkgName: pkgConfig:
    let
      package = pkgs.${pkgName} or (throw "Package ${pkgName} not found in pkgs");
    in
      wrapPackage { inherit package pkgConfig; name = pkgName; }
  ) config.bwrapper);
}
