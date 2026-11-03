# Eglantine: Switch 2 emulator forked from Eden. Built on top of the nixpkgs eden derivation.
# Sandboxed with NixPak; the real binary stays in passthru.unwrapped.
{
  lib,
  eden,
  fetchFromGitHub,
  applyPatches,
  fmt,
  httplib,
  sdl3,
  coreutils,
  adwaita-icon-theme,
  shared-mime-info,
  gamemode,
  mkNixPak,
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

  # Upstream hardcodes zstd_FORCE_BUNDLED (byte-identical NUP archives), so the system zstd is never used
  zstd = fetchFromGitHub {
    owner = "facebook";
    repo = "zstd";
    rev = "33618c89e511637f8a6ef955b3501766d71feb53";
    hash = "sha256-UP99PUq8N+fmU972Jxim4f9u//T+4hRW+wuTZzWg3uI=";
  };

  unwrapped = eden.overrideAttrs (
    _finalAttrs: oldAttrs: rec {
      pname = "eglantine";
      version = src.tag;

      src = fetchFromGitHub {
        tag = "build-212";
        owner = "Djihads80";
        repo = "Eglantine";
        hash = "sha256-Ca6CmK56GrZfr+ipRRBaI5AWAqoVL0lUhquz5PQqQ0I=";
      };

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

      cmakeFlags = oldAttrs.cmakeFlags ++ [
        (lib.cmakeBool "ENABLE_WERROR" false)
        (lib.cmakeBool "YUZU_CMD" false)
        (lib.cmakeBool "YUZU_ROOM" false)
        (lib.cmakeBool "YUZU_INSTALL_UDEV_RULES" true)
        # Default "custom" preset adds no -march (baseline x86-64). Desktop is Zen 3, laptop Zen 4.
        (lib.cmakeFeature "YUZU_BUILD_PRESET" "zen2")

        (lib.cmakeBool "zbic_FORCE_BUNDLED" true)
        (lib.cmakeFeature "zbic_CUSTOM_DIR" "${zbic}")
        (lib.cmakeFeature "zstd_CUSTOM_DIR" "${zstd}")
        (lib.cmakeBool "reshade_FORCE_BUNDLED" true)
        (lib.cmakeFeature "reshade_CUSTOM_DIR" "${reshade}")
      ];

      # nixpkgs' eden hooks reference dist/compatibility_list and 72-yuzu-input.rules, both gone upstream
      postConfigure = "";
      postInstall = "";

      # gamemode_client.h dlopens libgamemode.so by bare name; without this the request fails
      preFixup = oldAttrs.preFixup + ''
        qtWrapperArgs+=(--prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ gamemode ]})
      '';

      meta = oldAttrs.meta // {
        description = "Switch 2 emulator derived from Eden, Yuzu and Sudachi";
        homepage = "https://github.com/Djihads80/Eglantine";
        mainProgram = "eglantine";
        maintainers = [];
      };
    }
  );

in (mkNixPak {
  config = { config, sloth, ... }: {
    app.package = unwrapped;
    # Matches the installed .desktop file and icon
    flatpak.appId = "dev.eden_emu.eden";

    # Portals only. Not nixpakModules.gui-base: it also allows dconf, gvfs and the
    # a11y bus, binds the unfiltered at-spi socket (lets the app read other apps'
    # windows) and shares the host's font and shader caches read-write.
    dbus.policies = {
      "${config.flatpak.appId}" = "own";
      "${config.flatpak.appId}.*" = "own";
      "org.freedesktop.DBus" = "talk";
      "org.freedesktop.portal.*" = "talk";
    };

    gpu.enable = true;
    fonts.enable = true;
    locale.enable = true;
    timeZone.enable = true;

    bubblewrap = {
      network = false;
      newSession = true;
      dieWithParent = true;
      clearEnv = true;
      tmpfs = [ "/tmp" ];
      sockets = {
        wayland = true;
        pulse = true;
      };

      bind = {
        rw = [
          # Persistent sandbox home. Emulator data lands in <sandbox>/.local/share/eden
          # (keys, firmware, NAND), config in <sandbox>/.config/eden.
          [
            (sloth.mkdir (sloth.concat' sloth.xdgDataHome "/eglantine-sandbox"))
            sloth.homeDir
          ]
          # ROMs. The .desktop file's %f only works for files in here: arguments aren't bound.
          (sloth.concat' sloth.homeDir "/CryptVMs/Switch")
          # Files picked through the portal file chooser
          [
            (sloth.concat' sloth.runtimeDir "/doc/by-app/${config.flatpak.appId}")
            (sloth.concat' sloth.runtimeDir "/doc")
          ]
        ];
        # Controllers: SDL enumerates through udev
        ro = [
          "/sys/class"
          "/sys/bus"
          "/run/udev"
        ];
        dev = [
          # Also exposes keyboards
          "/dev/input"
          # gpu.enable covers /dev/dri only
          "/dev/nvidiactl"
          "/dev/nvidia0"
          "/dev/nvidia-uvm"
          "/dev/nvidia-modeset"
        ];
      };

      env = {
        HOME = sloth.homeDir;
        XDG_RUNTIME_DIR = sloth.runtimeDir;
        WAYLAND_DISPLAY = sloth.envOr "WAYLAND_DISPLAY" "wayland-0";
        XDG_SESSION_TYPE = "wayland";
        XDG_CURRENT_DESKTOP = sloth.envOr "XDG_CURRENT_DESKTOP" "";
        LANG = sloth.envOr "LANG" "C.UTF-8";
        XCURSOR_THEME = sloth.envOr "XCURSOR_THEME" "default";
        XCURSOR_SIZE = sloth.envOr "XCURSOR_SIZE" "24";
        PATH = lib.makeBinPath [ coreutils ];
        XDG_DATA_DIRS = lib.makeSearchPath "share" [
          adwaita-icon-theme
          shared-mime-info
        ];
        XCURSOR_PATH = "${adwaita-icon-theme}/share/icons";
        QT_QPA_PLATFORM = "wayland";
        # Chromium's own sandbox can't nest inside bwrap's user namespace
        QTWEBENGINE_DISABLE_SANDBOX = "1";
        # Switch 2 titles size the texture cache to the driver's VRAM budget minus 1 GiB
        # (texture_cache.h TickFrame, ignores vram_usage_mode). NVIDIA on Linux can't page VRAM
        # out, so niri and the lock screen fail to allocate and the desktop freezes (froze at
        # 14.07 GB total). The process runs ~1.1 GB over critical, so this leaves ~2.5 GB of the
        # 16 GB card; 9/10 GiB thrashed the collector in MKW. Drop once upstream caps it
        # (Eglantine #250, #279).
        # EDEN_NX2_TC_EXPECTED_MIB = "11264";
        # EDEN_NX2_TC_CRITICAL_MIB = "12288";
        # build-212 fixes this
        EDEN_NX2_SPLIT = "0"; # Fix issue #508 on build-212
      };
    };
  };
}).config.env
// { inherit unwrapped; }
