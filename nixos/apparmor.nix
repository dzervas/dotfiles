{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [ apparmor-parser ];

  # services.dbus.apparmor = "required";
  security.apparmor = {
    enable = true;
    # killUnconfinedConfinables = true;
    packages = with pkgs; [ roddhjav-apparmor-rules ];

    # TODO: Compile the profiles
    # policies = {
    #   firefox = {
    #     state = "complain";
    #     path = "${pkgs.roddhjav-apparmor-rules}/etc/apparmor.d/groups/browsers/firefox";
    #   };
    # };
  };
}
