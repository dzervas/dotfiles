{
  buildFHSEnv,
  makeDesktopItem,
  writeScript,
}: let
  installPath = "$HOME/.local/binaryninja";
in buildFHSEnv rec {
  name = "binaryninja";

  targetPkgs = pkgs:
    with pkgs; [
      dbus
      fontconfig
      freetype
      libGL
      libxkbcommon
      (python311.withPackages (p: with p; [ torch pip ]))
      xorg.libX11
      xorg.libxcb
      xorg.xcbutilimage
      xorg.xcbutilkeysyms
      xorg.xcbutilrenderutil
      xorg.xcbutilwm
      wayland
      zlib

      # Installer deps
      gnome-shell
      desktop-file-utils
      glib
    ];

  runScript = writeScript "binaryninja.sh" ''
    set -e
    export QT_QPA_PLATFORM=wayland
    exec "${installPath}/binaryninja" "$@"
  '';

  meta = {
    description = "BinaryNinja";
    platforms = ["x86_64-linux"];
  };

  desktopItem = makeDesktopItem {
    name = "BinaryNinja";
    desktopName = "Binary Ninja";
    comment = "Binary Ninja: A Reverse Engineering Platform";
    exec = "${installPath}/binaryninja";
    icon = "${installPath}/docs/img/logo.png";
    terminal = false;
    type = "Application";
    categories = "Development;ReverseEngineering;";
    mimeTypes = "application/x-binaryninja;x-scheme-handler/binaryninja;";
  };

  postInstall = ''
    mkdir -p $out/share/applications
    cp ${desktopItem}/share/applications/BinaryNinja.desktop $out/share/applications/
  '';
}
