{ lib, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      binaryninja = prev.callPackage ./binaryninja.nix {};
      opennoodl = prev.callPackage ./opennoodl.nix {};
      buspirate5-firmware = prev.callPackage ./buspirate5-firmware.nix {};

      vscode = prev.vscode.overrideAttrs (oldAttrs: let
        codelldb = final.vscode-extensions.vadimcn.vscode-lldb;
      in rec {
        plat = "linux-x64";

        # gha-updater: VERSION="$(curl https://update.code.visualstudio.com/api/releases/stable | jq -r '. | first')" && echo -n "$VERSION $(nix-prefetch-url https://update.code.visualstudio.com/$VERSION/linux-x64/stable)"
        version = "1.97.2";
        sha256 = "11a0y0zdz3mmc2xvpnlq06a7q06y6529xpp4hlhpjylj0bk06xn1";

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
