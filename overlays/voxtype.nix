{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  alsa-lib,
  llvmPackages,
  cmake,
  vulkan-headers,
  vulkan-loader,
  shaderc,
  git,
  wtype,
  makeWrapper,
}:
rustPlatform.buildRustPackage rec {
  pname = "voxtype";
  version = "0.6.6";

  src = fetchFromGitHub {
    owner = "peteonrails";
    repo = pname;
    tag = "v${version}";
    hash = "sha256-D0CgT0Avb7il6/GU8CtxWUGlMHhYZIPbHX952L4orDM=";
  };

  cargoHash = "sha256-h0b3H+79v8G28XNBDdCOZ+Vo+6wpfzckPCsDbRzp1m4=";
  buildFeatures = [ "gpu-vulkan" ];

  cmakeFlags = [
    "-DVulkan_INCLUDE_DIR=${vulkan-headers}/include"
    "-DVulkan_LIBRARY=${vulkan-loader}/lib/libvulkan.so"
    "-DVulkan_GLSLC_EXECUTABLE=${shaderc}/bin/glslc"
    (lib.cmakeBool "GGML_VULKAN" true)
  ];

  # CMAKE_ARGS = cmakeFlags;

  nativeBuildInputs = [
    rustPlatform.bindgenHook
    llvmPackages.libclang
    makeWrapper
    pkg-config
    shaderc
    cmake

    git
  ];

  buildInputs = [
    alsa-lib.dev
    vulkan-headers
    vulkan-loader
  ];

  postFixup = ''
    wrapProgram $out/bin/voxtype \
      --prefix PATH : ${lib.makeBinPath [ wtype ]}
  '';

  meta = with lib; {
    description = "Voice-to-text with push-to-talk for Wayland compositors";
    homepage = "https://github.com/peteonrails/voxtype";
    license = licenses.mit;
    maintainers = [];
  };
}
