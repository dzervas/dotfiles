# Upstream's prebuilt Lichii (clang + PGO) in the eglantine sandbox, to compare against the GCC source build.
# Patched for Nix instead of appimageTools.wrapType2: that runs it in its own bwrap FHS env, a second user
# namespace sandbox nested in NixPak's. Only the ELF interpreter and RUNPATHs change, the PGO code is untouched.
{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  autoPatchelfHook,
  alsa-lib,
  e2fsprogs,
  fontconfig,
  freetype,
  fribidi,
  gamemode,
  gmp,
  harfbuzz,
  libdrm,
  libglvnd,
  libgpg-error,
  libpulseaudio,
  libusb1,
  libx11,
  libxcb,
  libxkbcommon,
  vulkan-loader,
  wayland,
  zlib,
  callPackage,
}: let
  unwrapped = stdenv.mkDerivation rec {
    pname = "eglantine-appimage";
    version = "build-410";

    src = fetchurl {
      url = "https://github.com/zortos293/Lichii/releases/download/${version}/lichii-linux-x86_64-pgo.AppImage";
      hash = "sha256-HQAUyFh1nccKu1XL0UCf0X0JwJFDA+YTjvHq65lJgYU=";
    };

    appimageContents = appimageTools.extract { inherit pname version src; };

    dontUnpack = true;
    dontStrip = true;

    nativeBuildInputs = [ autoPatchelfHook ];

    # The base system libs linuxdeploy leaves out of the AppImage, plus the libs from the
    # binaries' .note.dlopen (SDL) that the sandbox can use: Vulkan and PulseAudio
    buildInputs = [
      stdenv.cc.cc.lib
      alsa-lib
      e2fsprogs # libcom_err
      fontconfig
      freetype
      fribidi
      gmp
      harfbuzz
      libdrm
      libglvnd
      libgpg-error
      libpulseaudio
      libusb1
      libx11
      libxcb
      libxkbcommon
      vulkan-loader
      wayland
      zlib
    ];

    # Optional SDL backends from .note.dlopen that the sandbox has no socket or use for (X11, PipeWire, JACK...)
    autoPatchelfIgnoreMissingDeps = [
      "libdecor-0.so.0"
      "libGLES_CM.so.1"
      "libjack.so.0"
      "libpipewire-0.3.so.0"
      "libsndio.so.7"
      "libsteam_api.so"
      "libXcursor.so.1"
      "libXi.so.6"
      "libXrandr.so.2"
      "libXss.so.1"
      "libXtst.so.6"
    ];

    # gamemode_client.h dlopens libgamemode.so by bare name
    runtimeDependencies = [ gamemode ];

    # Keeps the AppDir layout: the binaries' $ORIGIN/../lib RUNPATH and qt.conf's plugin path
    # are relative to usr/bin. eden-cli stays out of bin/, where it would bypass the sandbox.
    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib $out/bin $out/share
      cp -r ${appimageContents}/usr $out/lib/lichii
      chmod -R u+w $out/lib/lichii
      # Ubuntu's has /usr/share/X11/{xkb,locale} built in (Qt's Wayland plugin fails without a keymap);
      # nixpkgs' points at xkeyboard-config and libX11's compose tables in the store
      rm $out/lib/lichii/lib/libxkbcommon{,-x11}.so.0

      ln -s ../lib/lichii/bin/lichii $out/bin/lichii
      cp -r $out/lib/lichii/share/{applications,icons} $out/share/

      runHook postInstall
    '';

    meta = with lib; {
      description = "Switch 2 emulator derived from Eden, Yuzu and Sudachi (upstream PGO AppImage)";
      homepage = "https://github.com/zortos293/Lichii";
      license = licenses.gpl3Plus;
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
      mainProgram = "lichii";
      platforms = [ "x86_64-linux" ];
    };
  };
in callPackage ./eglantine-sandbox.nix { inherit unwrapped; }
