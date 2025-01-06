{
  lib,
  stdenv,
  cmake,
  python3,
  newlib,
  gcc-arm-embedded,
  picotool,
  pico-sdk,
  fetchFromGitHub,
}: let
  pico-sdk-subs = pico-sdk.override { withSubmodules = true ; };
in stdenv.mkDerivation rec {
  pname = "buspirate5-firmware";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "DangerousPrototypes";
    repo = "BusPirate5-firmware";
    rev = "9cb629309aacd44b1222b5b30150776264eacdaf";
    sha256 = "sha256-7uSkUrr/vNKk784a0VBaU8ercj4MLqTQVxca3t61onk=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [ cmake ];

  buildInputs = [
    python3
    newlib
    gcc-arm-embedded
    picotool
  ];

  cmakeFlags = [
    "-DCMAKE_C_COMPILER=${gcc-arm-embedded}/bin/arm-none-eabi-gcc"
    "-DCMAKE_CXX_COMPILER=${gcc-arm-embedded}/bin/arm-none-eabi-g++"
    "-DPICO_SDK_PATH=${pico-sdk-subs}/lib/pico-sdk"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DBP_PICO_PLATFORM=rp2040"
    "-DLEGACY_ANSI_COLOURS_ENABLED=false"
    "-DGIT_COMMIT_HASH=${src.rev}"
  ];

  installPhase = ''
    mkdir -p $out/share/buspirate5-firmware
    cp src/bus_pirate5_rev10.uf2 $out/share/buspirate5-firmware/
  '';

  meta = with lib; {
    description = "RP2040 project built with CMake and Pico SDK";
    homepage = "https://github.com/your_project"; # Replace with your project URL
    license = licenses.mit; # Replace with your project's license
    maintainers = with maintainers; [ your_name ]; # Replace with your maintainer handle
  };
}
