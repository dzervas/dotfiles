_: {
  nixpkgs.overlays = [
    (final: prev: {
      # atuin-desktop = prev.callPackage ./atuin-desktop.nix {};
      binaryninja = prev.callPackage ./binaryninja.nix {};
      opennoodl = prev.callPackage ./opennoodl.nix {};
      buspirate5-firmware = prev.callPackage ./buspirate5-firmware.nix {};
      flameshot = prev.flameshot.overrideAttrs (previousAttrs: {
        cmakeFlags = [
          "-DUSE_WAYLAND_CLIPBOARD=1"
          "-DUSE_WAYLAND_GRIM=1"
        ];
        buildInputs = previousAttrs.buildInputs ++ [ final.libsForQt5.kguiaddons ];
      });

      vscode = prev.vscode.overrideAttrs (oldAttrs: rec {
        plat = "linux-x64";

        #gha-updater: VERSION="$(curl https://update.code.visualstudio.com/api/releases/stable | jq -r '. | first')" && echo -n "$VERSION $(nix-prefetch-url https://update.code.visualstudio.com/$VERSION/linux-x64/stable)"
        version = "1.100.2";
        sha256 = "1h55vjyv6vy4vyzi6lypnh4jrng8dgb7i6l9rq6k94lbl3mbnb2w";

        src = prev.fetchurl {
          inherit sha256;
          name = "VSCode_${version}_${plat}.tar.gz";
          url = "https://update.code.visualstudio.com/${version}/${plat}/stable";
        };

        postInstall = oldAttrs.postInstall or "" + ''
          # Create a wrapper script for VSCode
          wrapProgram "$out/bin/code" \
            --set LD_LIBRARY_PATH "${final.stdenv.cc.cc.lib}/lib/"
        '';
      });
    })
  ];
}
