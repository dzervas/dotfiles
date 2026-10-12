{ inputs, lib, pkgs, ... }:
{
  imports = [ inputs.mango.nixosModules.mango ];
  home-manager.sharedModules = [
    inputs.mango.hmModules.mango
    ./home/mango.nix
  ];

  programs.mango.enable = true;

  services = {
    dbus.implementation = "broker";
    # Autologin once per boot (disk is LUKS); after logout/crash fall back to tuigreet.
    greetd = {
      enable = true;
      useTextGreeter = true;
      settings = {
        initial_session = { user = "dzervas"; command = "mango"; };
        default_session.command = "${lib.getExe pkgs.tuigreet} --time --remember --cmd mango";
      };
    };

    gvfs.enable = true;
    tumbler.enable = true;
    gnome.sushi.enable = true;
  };

  security.pam.services.login.enableGnomeKeyring = true;
  environment.systemPackages = with pkgs; [
    file-roller
    nautilus
  ];
}
