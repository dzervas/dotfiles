{ config, ... }:
{
  # TODO: Slow startup
  # TODO: Handle local file urls with nvim
  setup.terminal = "ghostty";
  programs.ghostty = {
    enable = true;
    installVimSyntax = true;
    settings = {
      background-opacity = 0.90;
      cursor-style = "block";
      cursor-style-blink = false;
      font-family = config.stylix.fonts.monospace.name;
      font-size = config.stylix.fonts.sizes.terminal;
      gtk-single-instance = true;
      shell-integration-features = "no-cursor"; # Fish sets cursor as bar

      window-decoration = "none";
      gtk-toolbar-style = "flat";
      gtk-wide-tabs = false;
      gtk-tabs-location = "bottom";

      gtk-custom-css = "./custom.css";

      keybind = [
        "shift+enter=text:\\n" # Claude Code fix
        "performable:ctrl+shift+f=write_screen_file:open"
        "performable:alt+r=toggle_command_palette"
        "performable:alt+shift+r=reload_config"
      ];
    };
  };

  xdg.configFile."ghostty/custom.css".text = ''
    /* Slimmer tab bar */
    tabbar tabbox {
      margin-top: 0;
      margin-bottom: 0;
    }
  '';
}
