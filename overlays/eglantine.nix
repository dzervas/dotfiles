# Eglantine: Switch 2 emulator forked from Eden. Built on top of the nixpkgs eden derivation.
# Sandboxed by eglantine-sandbox.nix; the real binary stays in passthru.unwrapped.
{
  lib,
  eden,
  fetchFromGitHub,
  applyPatches,
  fmt,
  httplib,
  sdl3,
  gamemode,
  callPackage,

  # Overridden by eglantine-dev (overlays/default.nix) to build a fork with the same recipe and sandbox.
  # Not named src: callPackage would fill that from the pkgs.src alias.
  eglantineSrc ? fetchFromGitHub {
    # tag = "build-341";
    # owner = "Djihads80";
    # repo = "Eglantine";
    tag = "build-341";
    owner = "zortos293";
    repo = "Lichii";
    hash = "sha256-ZrphcBJ3W3gcsG1ZXkD6hSdiaophZ0g93mr8CKExZJg=";
  },
  version ? eglantineSrc.tag,
  mainProgram ? "lichii",
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

  # Header-only, DOWNLOAD_ONLY since Lichii build-130 (externals/CMakeLists.txt)
  xxhash = fetchFromGitHub {
    owner = "Cyan4973";
    repo = "xxHash";
    tag = "v0.8.3";
    hash = "sha256-h6kohM+NxvQ89R9NEXZcYBG2wPOuB4mcyPfofKrx9wQ=";
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
      inherit version;
      src = eglantineSrc;

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
        (lib.cmakeBool "xxhash_FORCE_BUNDLED" true)
        (lib.cmakeFeature "xxhash_CUSTOM_DIR" "${xxhash}")
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
        inherit mainProgram;
        maintainers = [];
      };
    }
  );

in callPackage ./eglantine-sandbox.nix { inherit unwrapped; }
