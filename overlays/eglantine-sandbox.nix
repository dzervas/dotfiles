# NixPak sandbox shared by the eglantine packages. Takes the real build as `unwrapped`
# (source build or prebuilt AppImage) and keeps it in passthru.unwrapped.
{
  lib,
  coreutils,
  adwaita-icon-theme,
  shared-mime-info,
  mkNixPak,
  unwrapped,
}: (mkNixPak {
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
          # eglantine-dev's NVN2 direct mode: the lab's MKW shader library (EDEN_NX2_NVN_SHLIB)
          (sloth.concat' sloth.homeDir "/Lab/dotfiles/.pi/o72-replay/mkw-shaders")
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

        # MKW perf diagnostics in the log (dotfiles-vvt): texture cache usage vs its thresholds every
        # 600 frames; cache, process and driver memory every 2 s; per-thread breakdown of every frame
        # over 33 ms (turns on the GPU threads' zone timing, a little slower); guest thread report every 10 s.
        EDEN_NX2_TC_LOG = "1";
        EDEN_NX2_MEM_TRACE = "1";
        EDEN_NX2_STUTTER_TRACE = "1";
        EDEN_NX2_GUEST_THREAD_STATS = "1";
        # eglantine-dev's opt-in NVN2 direct renderer, passed through from the caller (empty reads as off)
        EDEN_NX2_NVN_DIRECT = sloth.envOr "EDEN_NX2_NVN_DIRECT" "";
        EDEN_NX2_NVN_SHLIB = sloth.envOr "EDEN_NX2_NVN_SHLIB" "";
      };
    };
  };
}).config.env
// { inherit unwrapped; }
