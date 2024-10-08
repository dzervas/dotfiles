{ bwrapperConfig }: self: super:
let
  lib = super.lib or self.lib;

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
      newSessionArg = if builtins.hasAttr "new-session" pkgConfig then [ "--new-session" ] else [];
      dieWithParentArg = if die-with-parent then [ "--die-with-parent" ] else [];
      unshareAllArg = if unshare-all then [ "--unshare-all" ] else [];
      shareNetArg = if share-net then [ "--share-net" ] else [];
    in
      newSessionArg ++ unshareAllArg ++ shareNetArg ++ dieWithParentArg ++ devArg ++ procArg ++ tmpfsArgs ++ setenvArgs ++ unsetenvArgs ++ devBindArgs ++ roBindArgs ++ bindArgs;

  wrapPackage = { name, package, pkgConfig }:
    super.stdenv.mkDerivation {
      pname = "${package.pname or name}-bwrap";
      version = package.version or "unknown";
      buildInputs = [ super.bubblewrap ];
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out/bin
        ${if builtins.hasAttr "customCommand" pkgConfig then ''
        cat > $out/bin/${name} <<EOF
        #!${super.runtimeShell}
        exec ${super.bubblewrap}/bin/bwrap ${lib.strings.concatStringsSep " " (buildBwrapArgs pkgConfig)} -- ${pkgConfig.customCommand} "\$@"
        EOF
        chmod +x $out/bin/${name}
        '' else ''
        for bin in ${package}/bin/*; do
          if [ -x "$bin" ]; then
            progName=$(basename $bin)
            cat > $out/bin/$progName <<EOF
        #!${super.runtimeShell}
        exec ${super.bubblewrap}/bin/bwrap ${lib.strings.concatStringsSep " " (buildBwrapArgs pkgConfig)} -- "$bin" "\$@"
        EOF
            chmod +x $out/bin/$progName
          fi
        done
        ''}
      '';
    };

in
  lib.genAttrs (builtins.attrNames bwrapperConfig) (name:
    let
      pkgConfig = bwrapperConfig.${name};
      package = super.${name} or (throw "Package ${name} not found in pkgs");
    in
      wrapPackage { inherit name package pkgConfig; }
  )
