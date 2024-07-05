{ pkgs, ... }:
let swaylock_cmd = "${pkgs.swaylock}/bin/swaylock -fF -c 1e1e1e";
in {
  services.swayidle = {
    enable = true;
    events = [
      { event = "before-sleep"; command = swaylock_cmd; }
    ];
    timeouts = [
      { timeout = 300; command = swaylock_cmd; }
      { timeout = 600; command = "${pkgs.sway}/bin/swaymsg \"output * dpms off\""; }
    ];
  };
}
