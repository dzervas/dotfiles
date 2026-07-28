{ pkgs, lib, ... }:
let
  # nixpkgs' brave has no `.override` (make-brave.nix is applied to extra args in
  # brave/default.nix), but home-manager's chromium module needs it for commandLineArgs
  brave = pkgs.brave // {
    override = { commandLineArgs ? "", ... }: pkgs.brave.overrideAttrs (old: {
      preFixup = old.preFixup + ''
        gappsWrapperArgs+=( --add-flags ${lib.escapeShellArg commandLineArgs} )
      '';
    });
  };
in
{
  # Issues:
  # - Can't install extensions defined below - see https://github.com/nix-community/home-manager/issues/2216
  # - Can't define chrome://flags
  # - Can't change settings
  # - Can't define custom search engine (kagi)

  setup.browser = "brave";

  # TODO: Make a new tab page with many things
  programs.chromium = {
    enable = true;
    package = brave;
    commandLineArgs = [
      "--ozone-platform=wayland"
      "--enable-features=WebRTCPipeWireCapturer"
      "--enable-features=VaapiVideoDecoder,VaapiIgnoreDriverChecks,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE"
      "--enable-logging=stderr"
      "--ignore-gpu-blocklist"
    ];
  };
}
