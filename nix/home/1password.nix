{ pkgs, ... }: {
  programs.ssh = {
    enable = true;
    extraConfig = ''
      Host *
      	IdentityAgent ~/.1password/agent.sock
    '';
  };

  programs.git = {
    extraConfig = {
      gpg.format = "ssh";
      # gpg.allowedSignersFile = "~/.gitconfig_allowed_signers";
      gpg."ssh".program = "${pkgs._1password-gui}/bin/op-ssh-sign";
    };
    # TODO: Better path?
    # signing.gpgPath = "/run/current-system/sw/bin/op-ssh-sign";
    signing.key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINMUrtMAAGoiU1XOUnw2toDLMKCrhWXPuH8VY9X79IRj";
    signing.signByDefault = true;
  };
}
