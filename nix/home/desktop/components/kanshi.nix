{ pkgs, ... }: {
  services.kanshi = {
    enable = true;
    settings = [
      {
        profile.name = "undocked";
        profile.outputs = [{ criteria = "eDP-1"; }];
      }
      {
        profile.name = "docked";
        profile.outputs = [
          {
            criteria = "eDP-1";
            status = "disable";
          }
          {
            criteria = "DP-4";
            status = "enable";
            position = "1920,0";
          }
          {
            criteria = "DP-5";
            status = "enable";
            position = "0,0";
          }
        ];
      }
    ];
  };
}