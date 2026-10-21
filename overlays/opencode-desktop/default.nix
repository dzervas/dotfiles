opencode: final: _prev: let
  inherit (final) lib;
  upstream = opencode.packages.${final.stdenv.hostPlatform.system};

  sand = final.writeScript "sand" ''
    #!${lib.getExe final.fish} --no-config
    function sand
      ${builtins.readFile ../../home/fish-functions/sand.fish}
    end
    sand $argv
  '';

  # Desktop's background service hosts every project, so it gets all of ~/Lab
  # plus OpenCode's real state: Desktop discovers it through service.json.
  server = final.writeScript "opencode-server" ''
    #!${lib.getExe final.fish} --no-config
    mkdir -p $HOME/.local/share/opencode $HOME/.local/state/opencode
    cd $HOME/Lab; or exit 1
    exec ${sand} \
      --ro-bind $HOME/.config/opencode:$HOME/.config/opencode \
      --bind $HOME/.local/share/opencode:$HOME/.local/share/opencode \
      --bind $HOME/.local/state/opencode:$HOME/.local/state/opencode \
      -c 'exec "$@"' -- -- $argv
  '';

  # Upstream Nix uses "prod", which writes service-prod.json while Desktop
  # discovers service.json. "latest" is the CLI's stable release channel;
  # Electron maps it to "prod" itself, so the native app identity stays the same.
  cli = upstream.opencode.overrideAttrs (oldAttrs: {
    env = oldAttrs.env // { OPENCODE_CHANNEL = "latest"; };
    patches = (oldAttrs.patches or []) ++ [ (final.replaceVars ./sandbox-commands.patch { inherit sand; }) ];
  });
in {
  opencode = cli;
  opencode-desktop = (upstream.opencode-desktop.override { opencode = cli; }).overrideAttrs (oldAttrs: {
    postPatch = oldAttrs.postPatch + ''
      substituteInPlace packages/desktop/src/main/service/background-service.ts \
        --replace-fail '...cli.command,' '"${server}", ...cli.command,'

      # Run the CLI from the store: a staged copy would be outside the sandbox
      # and keyed by version only, so a rebuild would keep running the old one.
      substituteInPlace packages/desktop/src/main/service/desktop-cli.ts \
        --replace-fail 'const binary = app.isPackaged || isolated ? yield* installCli(bundled, version) : bundled' 'const binary = bundled'

      # Nix, not electron-updater, owns this patched application.
      substituteInPlace packages/gui-extensions/src/updater/main.ts \
        --replace-fail 'const enabled = build.packaged && build.channel !== "dev"' 'const enabled = false'
    '';

    meta = oldAttrs.meta // {
      # The application is cross-platform; our bubblewrap integration is not.
      platforms = lib.intersectLists lib.platforms.linux oldAttrs.meta.platforms;
    };
  });
}
