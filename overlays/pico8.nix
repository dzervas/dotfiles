# https://github.com/danielbarter/nixos-pico8/blob/main/pico8.nix
{ pkgs, ...}: with pkgs; stdenv.mkDerivation rec {
  name = "pico-8";
  src = ../home/.private/pico-8_0.2.6b_amd64.zip;
  # TODO: move the pico8 zip to lfs

  buildInputs = [
    unzip
    patchelf
  ];

  inherit SDL2;

  LD_LIBRARY_PATH = let
    sdl_load_path = with xorg; [
      libX11
      libXext
      libXcursor
      libXinerama
      libXi
      libXrandr
      libXScrnSaver
      libXxf86vm
      libxcb
      libXrender
      libXfixes
      libXau
      libXdmcp
      udev

      libGL # OpenGL hardware acceleration
      libpulseaudio # Audio
      curl # Optional for splore
    ];
  in "${lib.makeLibraryPath sdl_load_path}";

  unpackPhase = "unzip $src";

  preFixup = ''
    patchelf \
      --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      $out/pico8

    patchelf \
      --replace-needed \
       libSDL2-2.0.so.0 $SDL2/lib/libSDL2-2.0.so.0 \
       $out/pico8_dyn
  '';

  desktopItem = makeDesktopItem {
    name = "Pico 8";
    exec = "pico8 -splore";
    icon = "pico8";
    desktopName = "Pico 8";
    categories = [ "Development" "Game" ];
  };

  installPhase = ''
    mkdir $out
    cp pico-8/* $out

    mkdir $out/bin
    echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH} $out/pico8 \$@" > $out/bin/pico8
    chmod 555 $out/bin/pico8

    mkdir -p $out/share/icons/hicolor/scalable/apps
    cp pico-8/lexaloffle-pico8.png $out/share/icons/hicolor/scalable/apps/pico8.png
    mkdir -p $out/share/applications
    cp ${desktopItem}/share/applications/*.desktop $out/share/applications
  '';
}
