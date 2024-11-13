_: {
  nixpkgs.overlays = [
    (final: prev: {
      binaryninja = prev.callPackage ./binaryninja.nix {};

      vscode = prev.vscode.overrideAttrs (oldAttrs: rec {
        plat = "linux-x64";

        # gha-updater: VERSION="$(curl https://update.code.visualstudio.com/api/releases/stable | jq -r '. | first')" && echo -n "$VERSION $(nix-prefetch-url https://update.code.visualstudio.com/$VERSION/linux-x64/stable)"
        version = "1.95.2";
        sha256 = "1d99kbvbd17h02m85gd8dircb39jsbifdk61w1hsvhri6dbfah8f";

        src = prev.fetchurl {
          inherit sha256;
          name = "VSCode_${version}_${plat}.tar.gz";
          url = "https://update.code.visualstudio.com/${version}/${plat}/stable";
        };
      });
    })
  ];
}
