{ lib, pkgs, ... }: with lib; {
  options.setup.bar = mkOption {
    type = types.str;
    description = "The program to use for running commands";
  };

  options.setup.browser = mkOption {
    type = types.str;
    description = "The web browser to use";
  };

  options.setup.locker = mkOption {
    type = types.str;
    default = "${pkgs._1password-gui}/bin/1password --lock";
    description = "The screen locking program to use";
  };

  options.setup.runner = mkOption {
    type = types.str;
    description = "The program to use for running commands";
  };

  options.setup.terminal = mkOption {
    type = types.str;
    description = "The terminal emulator to use";
  };
}
