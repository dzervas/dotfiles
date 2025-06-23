{ lib, ... }: with lib; {
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
      description = "The screen locking program to use";
    };

    lockerInstant = mkOption {
      type = types.str;
      description = "The screen locking program to use without any fades or wait times";
    };

    passwordManagerLock = mkOption {
      type = types.str;
      description = "How to lock the password manager";
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
