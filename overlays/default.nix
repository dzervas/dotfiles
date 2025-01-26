{ lib, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      binaryninja = prev.callPackage ./binaryninja.nix {};
      opennoodl = prev.callPackage ./opennoodl.nix {};
      buspirate5-firmware = prev.callPackage ./buspirate5-firmware.nix {};

      vscode-extensions.vadimcn.vscode-lldb = prev.vscode-extensions.vadimcn.vscode-lldb.overrideAttrs (oldAttrs: rec {
          src = prev.fetchFromGitHub {
            owner = "vadimcn";
            repo = "vscode-lldb";
            # gha-updater: LATEST="$(curl -Ls https://api.github.com/repos/vadimcn/vscode-lldb/releases/latest)" && echo -n "$(echo $LATEST | jq -jr .tag_name) $(nix-prefetch-url --unpack $(echo $LATEST | jq -jr .tarball_url))"
            rev = "v1.11.1";
            sha256 = "0m0la61b5ygdncwi42y1irqnxiia3d5n7c9596g9c3m25dqbfkkg";
          };
          version = lib.substring 1 20 src.rev;
      });

      vscode = prev.vscode.overrideAttrs (oldAttrs: let
        codelldb = final.vscode-extensions.vadimcn.vscode-lldb;
      in rec {
        plat = "linux-x64";

        # gha-updater: VERSION="$(curl https://update.code.visualstudio.com/api/releases/stable | jq -r '. | first')" && echo -n "$VERSION $(nix-prefetch-url https://update.code.visualstudio.com/$VERSION/linux-x64/stable)"
        version = "1.96.4";
        sha256 = "0grp4295kdamdc7w7bf06dzp4fcx41ry2jif9yx983dd0wgcgbrn";

        src = prev.fetchurl {
          inherit sha256;
          name = "VSCode_${version}_${plat}.tar.gz";
          url = "https://update.code.visualstudio.com/${version}/${plat}/stable";
        };

        additionalLibs = with prev; [
          zlib # Required by CodeLLDB
        ];

        patchCodeLLVM = prev.writeScript "patchCodeLLVM.sh" ''
          #!/usr/bin/env bash
          find ~/.vscode/extensions/ \
            -name codelldb \
            -type f -or -type l \
            -exec sh -c 'rm -f "$1" && ln -s "${codelldb}/${codelldb.installPrefix}/adapter/codelldb" "$1"' _ "{}" \;
        '';

        postInstall = oldAttrs.postInstall or "" + ''
          # Create a wrapper script for VSCode
          wrapProgram "$out/bin/code" \
            --set LD_LIBRARY_PATH "${final.stdenv.cc.cc.lib}/lib/"
        '';
      });
    })
  ];
}
