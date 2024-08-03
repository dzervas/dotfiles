{ ... }: {
  services.gammastep = {
    enable = true;
    tray = true;
    latitude = 39.6310014;
    longitude = 22.3829467;
    temperature = {
      day = 5500;
      night = 4000;
    };
  };
}
