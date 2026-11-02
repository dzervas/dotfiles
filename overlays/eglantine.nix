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
  coreutils,
  mkBwrap,
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

in mkBwrap {
  package = unwrapped;
  gpu = true;
  # Persistent sandbox home. Emulator data lands in <sandbox>/.local/share/eden
  # (keys, firmware, NAND), config in <sandbox>/.config/eden.
  home = "\${XDG_DATA_HOME:-$HOME/.local/share}/eglantine-sandbox";

  setup = ''
    runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(${coreutils}/bin/id -u)}"
    wayland_display="''${WAYLAND_DISPLAY:-wayland-0}"

    # hidraw for HIDAPI controllers
    shopt -s nullglob
    for node in /dev/hidraw*; do
      bwrap_extra+=(--dev-bind-try "$node" "$node")
    done
    shopt -u nullglob

    # Expose files passed on the command line (e.g. a ROM from the .desktop %f) read-only
    app_args=()
    for arg in "$@"; do
      if [[ -f "$arg" ]]; then
        arg="$(${coreutils}/bin/realpath "$arg")"
        bwrap_extra+=(--ro-bind "$arg" "$arg")
      fi
      app_args+=("$arg")
    done
    set -- "''${app_args[@]}"
  '';

  extraArgs = [
    "--new-session"
    "--chdir"
    "$HOME"
    "--perms"
    "0700"
    "--dir"
    "$runtime_dir"
  ];

  ro = [
    { path = "/etc/fonts"; try = true; }
    { path = "/etc/localtime"; try = true; }
    { path = "/etc/zoneinfo"; try = true; }

    # Controllers: SDL enumerates through udev. /dev/input also exposes keyboards.
    { path = "/sys/class"; try = true; }
    { path = "/sys/bus"; try = true; }
    { path = "/run/udev"; try = true; }

    "$runtime_dir/$wayland_display"
    { path = "$runtime_dir/pipewire-0"; try = true; }
    { path = "$runtime_dir/pulse/native"; try = true; }
  ];
  rw = [ "$HOME/CryptVMs/Switch" ];
  dev = [ { path = "/dev/input"; try = true; } ];

  env = {
    HOME = "$HOME";
    PATH = lib.makeBinPath [ coreutils ];
    XDG_RUNTIME_DIR = "$runtime_dir";
    WAYLAND_DISPLAY = "$wayland_display";
    QT_QPA_PLATFORM = "wayland";
    # Chromium's own sandbox can't nest inside bwrap's user namespace
    QTWEBENGINE_DISABLE_SANDBOX = "1";
  };

  # Session variables worth forwarding; everything else is dropped
  keepEnv = [
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
}
