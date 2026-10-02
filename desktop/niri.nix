{ lib, pkgs, ... }:
{
  home-manager.sharedModules = [ ./home/niri.nix ];

  niri-flake.cache.enable = false;

  programs.niri = {
    enable = true;
    package = pkgs.niri-unstable;
  };

  services = {
    dbus.implementation = "broker";
    # Autologin once per boot (disk is LUKS); after logout/crash fall back to tuigreet
    greetd = {
      enable = true;
      useTextGreeter = true;
      settings = {
        initial_session = { user = "dzervas"; command = "niri-session"; };
        default_session.command = "${lib.getExe pkgs.tuigreet} --time --remember --cmd niri-session";
      };
    };

    # XFCE File management
    # Mount, trash and more
    gvfs.enable = true;
    # Thumbnail support
    tumbler.enable = true;
  };

  # greetd's PAM stack includes login. Autologin skips auth, so the keyring
  # only auto-unlocks on tuigreet logins
  security.pam.services.login.enableGnomeKeyring = true;
  environment.systemPackages = with pkgs; [
    file-roller
    nautilus
  ];
  services.gnome.sushi.enable = true;
  # Calendar events - https://docs.noctalia.dev/getting-started/nixos/#calendar-events-support
  services.gnome.evolution-data-server.enable = true;
}
