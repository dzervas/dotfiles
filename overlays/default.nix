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
          file.dev # libmagic.so
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

        _settings = builtins.toJSON {

        };
      });
    })
  ];
}
