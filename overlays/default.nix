_: {
  nixpkgs.overlays = [
    (final: prev: {
      binaryninja = prev.callPackage ./binaryninja.nix {};

      vscode = prev.vscode.overrideAttrs (oldAttrs: rec {
        plat = "linux-x64";

        # gha-updater: VERSION="$(curl https://update.code.visualstudio.com/api/releases/stable | jq -r '. | first')" && echo -n "$VERSION $(nix-prefetch-url https://update.code.visualstudio.com/$VERSION/linux-x64/stable)"
        version = "1.95.3";
        sha256 = "0ijv2y2brc05m45slsy24dp8r0733d89f082l3mbs64vkz76s748";

        src = prev.fetchurl {
          inherit sha256;
          name = "VSCode_${version}_${plat}.tar.gz";
          url = "https://update.code.visualstudio.com/${version}/${plat}/stable";
        };
      });
    })
  ];
}
