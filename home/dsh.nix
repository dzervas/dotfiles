{ lib, pkgs, ... }: let
  # DeepSeek Harness runs every session, plugin and shell command in one process,
  # so the sandbox goes around that process. It is looser than pis: one server can
  # open any project under ~/Lab, and dsh confines its own shell commands with a
  # nested bwrap (bwrap comes from the bound per-user profile).
  dshSandbox = pkgs.mkNixPak {
    config = { sloth, ... }: {
      # Only the entrypoint: config.env greps the app tree with grep -R, which
      # follows pnpm's cyclic node_modules symlinks without end
      app = {
        package = pkgs.linkFarm "deepseek-harness-bin" [
          {
            name = "bin/dsh";
            path = lib.getExe pkgs.deepseek-harness;
          }
        ];
        binPath = "bin/dsh";
      };
      dbus.enable = false;

      bubblewrap = {
        network = true; # The web profile listens on 127.0.0.1 for the host browser
        dieWithParent = true;
        tmpfs = [ "/tmp" ];

        bind = {
          rw = [
            # Persistent sandbox home: pnpm's store, cache and state (plugin installs)
            # land here instead of the host's
            [
              "$HOME/.cache/dsh/home"
              "$HOME"
            ]
            "$HOME/.dsh"
            "$HOME/Lab"
          ];
          ro = [
            "/etc/static"
            "/etc/nix"
            "/etc/ssl"
            "/etc/passwd"
            "/etc/group"
            "/etc/nsswitch.conf"
            "/etc/protocols"
            "/etc/services"
            "/run/current-system/sw"
            (sloth.concat' "/etc/profiles/per-user/" (sloth.env "USER"))
            "/run/binfmt"
            "/bin"
            "/usr/bin"
            "/lib"
            "/lib64"

            "$HOME/.config/jj"
            "$HOME/.config/git"
            "$HOME/.config/gh-agent"
          ];
        };

        # NixPak can't unset variables (null panics the launcher), so the secrets pis
        # unsets are blanked instead
        env = lib.genAttrs [
          "VAULT_TOKEN"
          "AWS_ACCESS_KEY_ID"
          "AWS_SECRET_ACCESS_KEY"
          "AWS_SESSION_TOKEN"
          "AWS_PROFILE"
          "AZURE_CLIENT_ID"
          "AZURE_CLIENT_SECRET"
          "AZURE_TENANT_ID"
          "CLOUDFLARE_API_TOKEN"
          "DIGITALOCEAN_TOKEN"
          "DIGITALOCEAN_ACCESS_TOKEN"
          "GITHUB_TOKEN"
          "GH_TOKEN"
          "GITLAB_TOKEN"
          "GOOGLE_APPLICATION_CREDENTIALS"
          "OPENAI_API_KEY"
          "ANTHROPIC_API_KEY"
          "GEMINI_API_KEY"
          "SSH_AUTH_SOCK"
          "GPG_AGENT_INFO"
          "KRB5CCNAME"
        ] (_: "") // {
          GH_CONFIG_DIR = sloth.concat' sloth.homeDir "/.config/gh-agent";
        };
      };
    };
  };
in {
  # The package with bin/dsh replaced by the sandboxed launcher
  home.packages = [ dshSandbox.config.env ];

  # NixPak binds missing sources with --bind-try, which would silently leave these
  # on the sandbox's ephemeral root
  systemd.user.tmpfiles.rules = [
    "d %h/.dsh 0700 - - -"
    "d %h/.cache/dsh/home 0700 - - -"
  ];
}
