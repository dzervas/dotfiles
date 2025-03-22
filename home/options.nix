{ lib, pkgs, ... }: with lib; {
  options.setup = {
    bar = mkOption {
      type = types.str;
      description = "The program to use for running commands";
    };

    browser = mkOption {
      type = types.str;
      description = "The web browser to use";
    };

    locker = mkOption {
      type = types.str;
      default = "${pkgs._1password-gui}/bin/1password --lock";
      description = "The screen locking program to use";
    };

    runner = mkOption {
      type = types.str;
      description = "The program to use for running commands";
    };

    terminal = mkOption {
      type = types.str;
      description = "The terminal emulator to use";
    };

    isLaptop = mkOption {
      type = types.bool;
      default = false;
      description = "The current machine is a laptop";
    };

    windowManager = mkOption {
      type = types.str;
      description = "The used window manager";
    };
  };
}
