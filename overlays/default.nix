# To build a specific package:
# nix-build -E 'with import <nixpkgs> {}; callPackage ./overlays/<file> {}'
# or
# nix build --impure --expr 'let pkgs = import <nixpkgs> {}; in pkgs.callPackage /home/dzervas/Lab/dotfiles/overlays/<file> {}'
# To find the nix store path of a package:
# nix path-info --impure --expr 'let pkgs = import <nixpkgs> {}; in pkgs.callPackage /home/dzervas/Lab/dotfiles/overlays/<file> {}'
# To remove the build output of a nix store path:
# nix-store --delete /nix/store/hash
final: prev: {
  buspirate5-firmware = prev.callPackage ./buspirate5-firmware.nix { };
  claude-chrome = prev.callPackage ./claude-chrome.nix { };
  # nix-update:cursortab-nvim --subpackage server
  cursortab-nvim = prev.callPackage ./cursortab-nvim.nix { };
  # nix-update:codex-latest
  codex-latest = prev.callPackage ./codex.nix { };
  # nix-update:anytype-cli
  anytype-cli = prev.callPackage ./anytype-cli.nix { };
  # nix-update :n8n-cli --version-regex 'n8n@(2\.\d+\.\d+)'
  n8n-cli = prev.callPackage ./n8n-cli.nix { };

  _1password-gui = prev._1password-gui.overrideAttrs (oldAttrs: {
     postInstall = (oldAttrs.postInstall or "") + ''
       patchelf --set-interpreter \
         "$(patchelf --print-interpreter "$out/share/1password/op-ssh-sign")" \
         "$out/share/1password/1password-mcp"
       patchelf --set-rpath \
         "$(patchelf --print-rpath "$out/share/1password/op-ssh-sign")" \
         "$out/share/1password/1password-mcp"

       ln -s "$out/share/1password/1password-mcp" "$out/bin/1password-mcp"
     '';
   });

  # nix-update:pi-coding-agent-latest --custom-dep modelData
  # Broken:
  pi-coding-agent-latest = prev.pi-coding-agent.overrideAttrs (
    finalAttrs: _prevAttrs: rec {
      version = "0.84.4";

      src = final.fetchFromGitHub {
        owner = "earendil-works";
        repo = "pi";
        tag = "v${version}";
        hash = "sha256-7z8OXao1PzmBEepDkIqVqyfQBPHulBlKcGymDYsnMvc=";
      };

      npmDepsHash = "sha256-35GC3Q4Jf4URvqoEYHeM63x49tTmrth62//PvKm4I7Q=";

      npmDeps = final.fetchNpmDeps {
        inherit (finalAttrs) src;
        name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
        hash = finalAttrs.npmDepsHash;
      };

      modelData = final.fetchurl {
        url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${version}.tgz";
        hash = "sha256-39PJKc7lpzhxmaCiTfwb4glvHqj1n/uChRmKDtAev5M=";
      };
    }
  );
}
