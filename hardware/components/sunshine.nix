{ lib, pkgs, ... }: {
  # Game streaming host for Moonlight. Steam Remote Play can't use NVENC on RTX 50 (no 32-bit CUDA)
  # No capSysAdmin (KMS capture): Sunshine auto-picks wlr-screencopy capture under Hyprland,
  # and the Vulkan encoder since the nixpkgs build has no CUDA (needed for NVENC)
  services.sunshine = {
    enable = true;
    openFirewall = true;
    autoStart = false;

    applications.apps = [
      {
        name = "Eglantine";
        # Runs in the foreground so the stream ends when the emulator exits
        cmd = lib.getExe pkgs.eglantine;
      }
    ];
  };
}
