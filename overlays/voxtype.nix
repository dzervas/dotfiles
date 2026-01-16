# nix-update:voxtype
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
  version = "0.4.14";

  src = fetchFromGitHub {
    owner = "peteonrails";
    repo = pname;
    tag = "v${version}";
    hash = "sha256-8H3tohZcFbech1VOg3EP9iXDLh3aZR2mkLdVsPLYu7A=";
  };

  cargoHash = "sha256-9KImGiaVzBPp6kVVCwbdoK/yULS17+eNq6+tl7i1vBQ=";
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
