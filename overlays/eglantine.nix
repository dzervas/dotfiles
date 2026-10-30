# Eglantine: Switch 2 emulator forked from Eden. Built on top of the nixpkgs eden derivation.
# Only a bubblewrap wrapper ends up in bin/; the real binary stays in passthru.unwrapped.
{
  lib,
  eden,
  fetchFromGitHub,
  applyPatches,
  fmt,
  httplib,
  sdl3,
  bubblewrap,
  coreutils,
  writeShellApplication,
  runCommand,
}: let
  # Upstream pins httplib 0.46 (cpmfile.json); nixpkgs' eden pins an older one and the latest is untested.
  httplib' = httplib.overrideAttrs (
    finalAttrs: _oldAttrs: {
      version = "0.46.0";
      src = fetchFromGitHub {
        owner = "yhirose";
        repo = "cpp-httplib";
        tag = "v${finalAttrs.version}";
        hash = "sha256-Vzr51oo344jFNwmqdtLWxClJpuCTzmnMqXyLCz8UZj4=";
      };
    }
  );

  # DOWNLOAD_ONLY CPM packages: no find_package path exists, so they're fed in via <name>_CUSTOM_DIR
  zbic = fetchFromGitHub {
    owner = "kinnay";
    repo = "zbic";
    rev = "11b08f2712264bbed731545085cbd9702096ceb7";
    hash = "sha256-pHvxa1gkUvQo6mUgmLWtj1kcu01BLdGmttZyb8ZAj/o=";
  };

  src = fetchFromGitHub {
    owner = "Djihads80";
    repo = "Eglantine";
    rev = "adae7635708e155d967e84d7ad84bf63c5203409";
    hash = "sha256-weEQTzN1+c1vmOcsh0dzVR5jqYCOBcqwmKR1Ob1+5LM=";
  };

  # CPMUtil skips cpmfile patches for <name>_CUSTOM_DIR, so apply upstream's reshade patch here
  reshade = applyPatches {
    name = "reshade-6.8.0-patched";
    src = fetchFromGitHub {
      owner = "crosire";
      repo = "reshade";
      tag = "v6.8.0";
      hash = "sha256-K6QC7CLqy8M318n9WbuqGvcRF9g9abvDD/xbr7T+nXo=";
    };
    patches = [ "${src}/.patch/reshade/0001-from-chars-fallback.patch" ];
  };

  unwrapped = eden.overrideAttrs (
    _finalAttrs: oldAttrs: {
      pname = "eglantine";
      version = "0-unstable-2026-11-01";
      inherit src;

      # Upstream moved to SDL3 and fmt 12
      buildInputs = builtins.filter (
        p:
        !builtins.elem (lib.getName p) [
          "sdl2-compat"
          "fmt"
          "httplib"
        ]
      ) oldAttrs.buildInputs
      ++ [
        fmt
        httplib'
        sdl3
      ];

      # The NX2 dynarmic decoder changes are not covered by upstream's test expectations
      doCheck = false;

      cmakeFlags = oldAttrs.cmakeFlags ++ [
        (lib.cmakeBool "ENABLE_WERROR" false)
        (lib.cmakeBool "YUZU_CMD" false)
        (lib.cmakeBool "YUZU_ROOM" false)
        (lib.cmakeBool "YUZU_INSTALL_UDEV_RULES" true)

        (lib.cmakeBool "zbic_FORCE_BUNDLED" true)
        (lib.cmakeFeature "zbic_CUSTOM_DIR" "${zbic}")
        (lib.cmakeBool "reshade_FORCE_BUNDLED" true)
        (lib.cmakeFeature "reshade_CUSTOM_DIR" "${reshade}")
      ];

      # nixpkgs' eden hooks reference dist/compatibility_list and 72-yuzu-input.rules, both gone upstream
      postConfigure = "";
      postInstall = "";

      meta = oldAttrs.meta // {
        description = "Switch 2 emulator derived from Eden, Yuzu and Sudachi";
        homepage = "https://github.com/Djihads80/Eglantine";
        mainProgram = "eglantine";
        maintainers = [];
      };
    }
  );

  # Session variables worth forwarding; everything else is dropped by --clearenv
  passEnv = [
    "LANG"
    "LANGUAGE"
    "LC_ALL"
    "LOCALE_ARCHIVE"
    "TZ"
    "USER"
    "LOGNAME"
    "XDG_CURRENT_DESKTOP"
    "XDG_SESSION_TYPE"
    "XDG_DATA_DIRS"
    "XCURSOR_THEME"
    "XCURSOR_SIZE"
    "XCURSOR_PATH"
    "QT_QPA_PLATFORMTHEME"
    "QT_STYLE_OVERRIDE"
    "QT_WAYLAND_DECORATION"
    "__GLX_VENDOR_LIBRARY_NAME"
    "__EGL_VENDOR_LIBRARY_FILENAMES"
    "VK_ICD_FILENAMES"
    "VK_DRIVER_FILES"
    "GBM_BACKEND"
  ];

  sandboxed = writeShellApplication {
    name = "eglantine";
    runtimeInputs = [
      bubblewrap
      coreutils
    ];
    text = ''
      # Persistent sandbox home. Emulator data lands in <sandbox>/.local/share/eden
      # (keys, firmware, NAND), config in <sandbox>/.config/eden.
      sandbox_home="''${XDG_DATA_HOME:-$HOME/.local/share}/eglantine-sandbox"
      runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      mkdir -p "$sandbox_home"

      bwrap_args=(
        --unshare-all
        --die-with-parent
        --new-session
        --clearenv
        --proc /proc
        --dev /dev
        --tmpfs /tmp

        --ro-bind /nix/store /nix/store
        --ro-bind /etc/static /etc/static
        --ro-bind-try /etc/fonts /etc/fonts
        --ro-bind-try /etc/localtime /etc/localtime
        --ro-bind-try /etc/zoneinfo /etc/zoneinfo
        --ro-bind /etc/passwd /etc/passwd
        --ro-bind /etc/group /etc/group
        --ro-bind-try /run/current-system/sw /run/current-system/sw
        --ro-bind-try "/etc/profiles/per-user/$USER" "/etc/profiles/per-user/$USER"

        # GPU
        --ro-bind-try /run/opengl-driver /run/opengl-driver
        --ro-bind-try /sys/dev/char /sys/dev/char
        --ro-bind-try /sys/devices /sys/devices

        # Controllers: SDL enumerates through udev. /dev/input also exposes keyboards.
        --ro-bind-try /sys/class /sys/class
        --ro-bind-try /sys/bus /sys/bus
        --ro-bind-try /run/udev /run/udev
        --dev-bind-try /dev/input /dev/input

        --bind "$sandbox_home" "$HOME"
        --perms 0700 --dir "$runtime_dir"
        --ro-bind "$runtime_dir/''${WAYLAND_DISPLAY:-wayland-0}" "$runtime_dir/''${WAYLAND_DISPLAY:-wayland-0}"
        --ro-bind-try "$runtime_dir/pipewire-0" "$runtime_dir/pipewire-0"
        --ro-bind-try "$runtime_dir/pulse/native" "$runtime_dir/pulse/native"
        --bind "$HOME/CryptVMs/Switch" "$HOME/CryptVMs/Switch"

        --chdir "$HOME"
        --setenv HOME "$HOME"
        --setenv PATH "${lib.makeBinPath [ coreutils ]}"
        --setenv XDG_RUNTIME_DIR "$runtime_dir"
        --setenv WAYLAND_DISPLAY "''${WAYLAND_DISPLAY:-wayland-0}"
        --setenv QT_QPA_PLATFORM wayland
        # Chromium's own sandbox can't nest inside bwrap's user namespace
        --setenv QTWEBENGINE_DISABLE_SANDBOX 1
      )

      for name in ${lib.escapeShellArgs passEnv}; do
        if [[ -n "''${!name:-}" ]]; then
          bwrap_args+=(--setenv "$name" "''${!name}")
        fi
      done

      # Render nodes only, plus NVIDIA's nodes and hidraw for HIDAPI controllers
      shopt -s nullglob
      for node in /dev/dri/renderD* /dev/nvidiactl /dev/nvidia[0-9]* /dev/nvidia-uvm /dev/nvidia-modeset /dev/hidraw*; do
        bwrap_args+=(--dev-bind-try "$node" "$node")
      done

      # Expose files passed on the command line (e.g. a ROM from the .desktop %f) read-only
      app_args=()
      for arg in "$@"; do
        if [[ -f "$arg" ]]; then
          arg="$(realpath "$arg")"
          bwrap_args+=(--ro-bind "$arg" "$arg")
        fi
        app_args+=("$arg")
      done

      exec bwrap "''${bwrap_args[@]}" -- ${lib.getExe unwrapped} "''${app_args[@]}"
    '';
  };
in runCommand "eglantine-${unwrapped.version}"
  {
    passthru = { inherit unwrapped; };
    meta = {
      inherit (unwrapped.meta)
        description
        homepage
        license
        platforms
        ;
      mainProgram = "eglantine";
    };
  }
  ''
    mkdir -p $out/bin $out/lib
    ln -s ${lib.getExe sandboxed} $out/bin/eglantine
    ln -s ${unwrapped}/share $out/share
    ln -s ${unwrapped}/lib/udev $out/lib/udev
  ''
