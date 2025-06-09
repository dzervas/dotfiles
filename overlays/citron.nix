# https://github.com/knoopx/nix/blob/720729e47d7f41b74a48e5714c1f5ea8c9cbbf48/pkgs/gaming/emulation/sudachi/default.nix
# More here: https://github.com/liberodark/my-flakes/tree/master
# and: https://github.com/NixOS/nixpkgs/issues/369905
{pkgs, ...}: let
  tzdb_to_nx = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "tzdb_to_nx";
    version = "221202";
    src = pkgs.fetchurl {
      url = "https://github.com/lat9nq/tzdb_to_nx/releases/download/${version}/${version}.zip";
      hash = "sha256-mRzW+iIwrU1zsxHmf+0RArU8BShAoEMvCz+McXFFK3c=";
    };
    nativeBuildInputs = [
      pkgs.unzip
    ];
    buildCommand = "unzip $src -d $out";
  };
in
  pkgs.stdenv.mkDerivation rec {
    pname = "citron-emu";
    version = "3635b6e6026623134242bb58d4f60240960756db";

    src =
      fetchGit
      {
        url = "https://git.citron-emu.org/Citron/Citron.git";
        rev = version;
        submodules = true;
      };

    nativeBuildInputs = with pkgs; [
      cmake
      pkg-config
      kdePackages.wrapQtAppsHook
      libtool
      git
      glslang
    ];

    buildInputs = with pkgs; [
      git
      # vulkan-headers
      # vulkan-utility-libraries
      boost183
      autoconf
      automake
      fmt
      llvm_19
      nasm
      lz4
      nlohmann_json
      ffmpeg
      qt6.qtbase
      qt6.qtmultimedia
      qt6.qtwebengine
      enet
      libva
      vcpkg
      libopus
      udev
      SDL2
    ];

    dontFixCmake = true;
    env.NIX_CFLAGS_COMPILE = "-march=native";

    cmakeFlags = [
      "-DCITRON_CHECK_SUBMODULES=OFF"
      "-DENABLE_QT6=ON"
      "-DCITRON_USE_BUNDLED_FFMPEG=OFF"
      "-DCITRON_USE_BUNDLED_VCPKG=OFF"
      # "-DCITRON_USE_EXTERNAL_VULKAN_HEADERS=OFF"
      # "-DCITRON_USE_EXTERNAL_VULKAN_UTILITY_LIBRARIES=OFF"
      "-DCITRON_USE_EXTERNAL_SDL2=OFF"
      "-DCITRON_TESTS=OFF"
    ];

    #substituteInPlace CMakeLists.txt --replace-fail "VulkanHeaders 1.3.301" "VulkanHeaders 1.3"
    preConfigure = ''
      substituteInPlace externals/nx_tzdb/CMakeLists.txt --replace-fail "set(CAN_BUILD_NX_TZDB true)" "set(CAN_BUILD_NX_TZDB false)"
      mkdir -p build/externals/nx_tzdb
      ln -s ${tzdb_to_nx} build/externals/nx_tzdb/nx_tzdb
    '';

    meta.mainProgram = "citron";
  }
