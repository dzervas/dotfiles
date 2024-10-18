{
  buildFHSEnv,
  makeDesktopItem,
  python3,
  symlinkJoin,
  writeScript,
}: let
  # TODO: Use the config.xdg.dataHome
  # TODO: Build coolsigmaker & binja-msvc
  installPath = "/home/dzervas/.local/share/binaryninja";
  program = buildFHSEnv rec {
    name = "binaryninja";

    python = python3.withPackages (p: with p; [ torch pip ]);
    targetPkgs = pkgs:
      with pkgs; [
        dbus
        file # for libmagic.so
        fontconfig
        freetype
        libGL
        libxkbcommon
        libxml2
        xorg.libX11
        xorg.libxcb
        xorg.xcbutilimage
        xorg.xcbutilkeysyms
        xorg.xcbutilrenderutil
        xorg.xcbutilwm
        wayland
        zlib
        python

        # Installer deps
        gnome-shell
        desktop-file-utils
        glib
      ];

    runScript = writeScript "binaryninja.sh" ''
      set -e
      export QT_QPA_PLATFORM=wayland
      export PATH="${python}/bin:$PATH"
      export PYTHONPATH="${python}/lib/python3.12/site-packages:$PYTHONPATH"
      exec "${installPath}/binaryninja" "$@"
    '';

    meta = {
      description = "BinaryNinja";
      platforms = ["x86_64-linux"];
    };
  };
  desktopItem = makeDesktopItem {
    name = "BinaryNinja";
    desktopName = "Binary Ninja";
    comment = "Binary Ninja: A Reverse Engineering Platform";
    exec = "${program}/bin/binaryninja";
    icon = "${installPath}/docs/img/logo.png";
    terminal = false;
    type = "Application";
    categories = [ "Development" ];
    mimeTypes = [ "application/x-binaryninja" "x-scheme-handler/binaryninja" ];
  };
in
  symlinkJoin {
    name = "binaryninja";
    paths = [desktopItem program];

    meta = {
      inherit (program.meta) description platforms;
      homepage = "https://binary.ninja/";
    };
  }
