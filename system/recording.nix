_: {
  # Script that fires when a recording stream gets created and when it ends
  services.pipewire.wireplumber = {
    extraScripts."recording-sign.lua" = ''
      local om = ObjectManager {
        Interest {
          type = "node",
          Constraint { "media.class", "matches", "Stream/Input/*" },
          -- Constraint { "media.class", "matches", "Video/Source" },
          -- Optional: Add more specific constraints
          -- Constraint { "node.name", "matches", "*camera*" }, -- Only camera sources
          -- or
          -- Constraint { "api.v4l2.path", "exists" }, -- Only V4L2 video devices
        }
      }

      om:connect("objects-changed", function (om)
        for node in om:iterate() do
          print("Input stream created: " .. (node.properties["node.name"] or "Unknown"))
          print("Stream description: " .. (node.properties["node.description"] or "N/A"))
          print("Media role: " .. (node.properties["media.role"] or "N/A"))
          print("Media role: " .. (node.properties["media.class"] or "N/A"))
          print("Application: " .. (node.properties["application.name"] or "Unknown"))
          print("---")
        end
      end)

      om:activate()
      print("ObjectManager activated")
    '';

    # extraConfig."99-recording-sign" = {
    #   "wireplumber.components" = [
    #     {
    #       name = "recording-sign.lua";
    #       type = "script/lua";
    #       provides = "custom.recording-sign";
    #     }
    #   ];
    #
    #   "wireplumber.profiles" = {
    #     main = {
    #       "custom.recording-sign" = "required";
    #     };
    #   };
    # };
  };
}
