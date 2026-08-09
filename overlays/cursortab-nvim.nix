{
  lib,
  buildGoModule,
  fetchFromGitHub,
  vimUtils,
}:
let
  version = "unstable-2026-08-05";
  src = fetchFromGitHub {
    owner = "cursortab";
    repo = "cursortab.nvim";
    rev = "53c336bd01afa9160935e4423a424c2adc8160be";
    hash = "sha256-MTRz8vPJ+mo6K4dWNlTtxZcEA+pSHWp4cJs/WQTl1H4=";
  };
  server = buildGoModule {
    pname = "cursortab";
    inherit version src;
    modRoot = "server";
    vendorHash = "sha256-4S14Vm2Ju084uxB2Zlku4z5AmIZkNZkQpiNgYrcqIbg=";
  };
in
vimUtils.buildVimPlugin {
  pname = "cursortab.nvim";
  inherit version src;

  postPatch = ''
    sed -i '/^[[:space:]]*".env\(\.\*\)\?",$/d' lua/cursortab/config.lua
  '';

  postInstall = ''
    rm -rf $out/server
    mkdir $out/server
    ln -s ${server}/bin/cursortab $out/server/cursortab

    find $out -mindepth 1 -maxdepth 1 \
      ! -name lua ! -name doc ! -name server \
      -exec rm -rf {} +
  '';

  meta = {
    description = "Local edit completions and cursor predictions for Neovim";
    homepage = "https://github.com/cursortab/cursortab.nvim";
    license = lib.licenses.mit;
  };
}
