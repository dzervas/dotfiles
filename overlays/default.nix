_: {
  nixpkgs.overlays = [
    (final: prev: {
      opennoodl = prev.callPackage ./opennoodl.nix {};
      buspirate5-firmware = prev.callPackage ./buspirate5-firmware.nix {};
      pico8 = prev.callPackage ./pico8.nix {};
      flameshot = prev.flameshot.overrideAttrs (prevAttrs: {
        cmakeFlags = [
          "-DUSE_WAYLAND_CLIPBOARD=1"
          "-DUSE_WAYLAND_GRIM=1"
        ];
        buildInputs = prevAttrs.buildInputs ++ [ final.libsForQt5.kguiaddons ];
      });

      binaryninja = prev.binaryninja-free.overrideAttrs (prevAttrs: {
        pname = "binaryninja";
        version = "5.1.8104";
        src = ../home/.private/apps/binaryninja_linux_stable_personal.zip;

        # To make the venv: cd ~/.binaryninja && python -m venv venv
        nativeBuildInputs = prevAttrs.nativeBuildInputs ++ [ final.kdePackages.wrapQtAppsHook ];
        buildInputs = with final; [
          # file.dev # libmagic.so
          openssl.dev

          qt6.qtbase
          qt6.qtdeclarative
          qt6.qtshadertools
          qt6.qtwayland
        ] ++ prevAttrs.buildInputs;

        desktopItems = [
          ((builtins.elemAt prevAttrs.desktopItems 0).override {
            desktopName = "Binary Ninja";
          })
        ];

        # TODO: Move the settings.json here
      });

      openvpn-aws = prev.openvpn.overrideAttrs (prevAttrs: {
        pname = "openvpn-aws";
        patches = (prevAttrs.patches or []) ++ [
          # From https://github.com/samm-git/aws-vpn-client/blob/master/openvpn-v2.6.12-aws.patch
          ./openvpn-aws-v2.6.12.patch
        ];

        # install an extra binary named openvpn-aws (and its manpage symlink)
        postInstall = (prevAttrs.postInstall or "") + ''
          # Some nixpkgs versions put it in $out/sbin; normalize:
          if [ -x "$out/sbin/openvpn" ]; then
            mkdir -p "$out/bin"
            mv "$out/sbin/openvpn" "$out/bin/openvpn"
          fi

          cp "$out/bin/openvpn" "$out/bin/openvpn-aws"

          # Man page (if present)
          if [ -e "$out/share/man/man8/openvpn.8.gz" ]; then
            ln -s "openvpn.8.gz" "$out/share/man/man8/openvpn-aws.8.gz" || true
          fi
        '';

        # so `nix run .#openvpn-aws` picks the right binary
        meta = (prevAttrs.meta or {}) // { mainProgram = "openvpn-aws"; };
      });
    })
  ];
}
