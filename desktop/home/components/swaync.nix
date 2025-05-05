_: {
  services.swaync = {
    enable = true;
    settings = {
      hide-on-clear = true;
      widgets = ["inhibitors" "dnd" "mpris" "notifications"];
      widget-config = {
        inhibitors = {
          text = "Inhibitors";
          button-text = "Clear All";
          clear-all-button = true;
        };
        mpris = {
          image-size = 96;
          blur = true;
        };
      };
    };
  };

  programs = {
    waybar.settings.mainBar."custom/notifications" = let
      # indicator = "<span foreground='red'><sup></sup></span>";
      indicator = "";
    in {
      tooltip = false;
      format = "{icon}";
      format-icons = {
        notification = "${indicator}";
        none = "";
        dnd-notification = "${indicator}";
        dnd-none = "";
        inhibited-notification = "${indicator}";
        inhibited-none = "";
        dnd-inhibited-notification = "${indicator}";
        dnd-inhibited-none = "";
      };
      return-type = "json";
      exec-if = "which swaync-client";
      exec = "swaync-client -swb";
      on-click = "swaync-client -t -sw";
      on-click-right = "swaync-client -d -sw";
      escape = true;
    };
  };
}
