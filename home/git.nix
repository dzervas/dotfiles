{ config, pkgs, ... }: {
  # TODO: Somehow integrate [includeIf "hasconfig:remote.*.url:git@github.com:<organisation>/**"] in a safe way

  home.packages = with pkgs; [git-lfs];
  programs = rec {
    git = {
      enable = true;

      userName = "Dimitris Zervas";
      userEmail = "dzervas@dzervas.gr";
      signing.signByDefault = true;

      difftastic = {
        enable = true;
        display = "side-by-side";
      };

      aliases = {
        aa = "!git add -A && git status";
        ac = "!git aa && git commit";
        acp = "!git ac && git push";
        bl = "!git reflog show --pretty=format:'%gs ~ %gd' --date=relative | grep 'checkout:' | grep -oE '[^ ]+ ~ .*' | awk -F~ '!seen[$1]++' | head -n 10 | awk -F' ~ HEAD@{' '{printf(\"  \\033[33m%s: \\033[37m %s\\033[0m\\n\", substr($2, 1, length($2)-1), $1)}'";
        c = "clone";
        co = "checkout";
        d = "diff";
# get-ignore = "!"f(){ curl -L --silent --fail "https://github.com/github/gitignore/raw/main/$1.gitignore" >> .gitignore && echo "Appended to .gitignore" || echo -e "No gitignore found for $1 - check out https://github.com/github/gitignore"; }; f"";
        get-ignore = "!gi(){ curl -fsL \"https://www.toptal.com/developers/gitignore/api/$1\" >> .gitignore && echo \"Appended to .gitignore\" || echo \"No gitignore found - check out gitignore.io\"; }; gi";
        ll = "log --graph --decorate --abbrev-commit --pretty='%C(auto)%h %d %s %Cgreen(%cr)%Creset [%C(bold blue)%an%Creset %G?]'";
        lla = "log --graph --decorate --abbrev-commit --pretty='%C(auto)%h %d %s %Cgreen(%cr)%Creset [%C(bold blue)%an%Creset  %G?]' --all";
# Parse positional params
        hub = "!f() { grep -q '/' <<< $1 && git clone git@github.com:$1 || git clone git@github.com:dzervas/$1; }; f";
        oops = "!echo 'Going to amend and force push. You sure?' && read && git add -A && git commit --amend --no-edit && git push --force-with-lease";
        s = "status";
        undo = "reset HEAD~";
      };

      extraConfig = {
        checkout.defaultRemote = "origin";
        init.defaultBranch = "main";

        color.ui = "auto";
        core.autocrlf = "input";
        web.browser = "firefox";
        pull.rebase = true;

# Output stuff
        branch.sort = "-committerdate";
        log.date = "local";
        tag.sort = "version:refname";

        gpg.ssh.allowedSignersFile = ".config/git/allowed-signers";

        push = {
          default = "current";
          followTags = true;
        };

        diff = {
          srcprefix = "-h";
          zip.textconv = "unzip -c -a";
        };

        difftool.prompt = false;
      };

      ignores = [
        "*~"
          "*.swp"
          ".envrc"
          ".direnv"
          ".shell.nix"
      ];
    };

    jujutsu = {
      enable = true;
      settings = {
        user = {
          name = git.userName;
          email = git.userEmail;
        };

        aliases = {
          d = ["diff"];
          s = ["status"];
          ll = ["log"];
        };

        git.auto-local-bookmark = true;

        # Sign all commits owned by us
        signing.behavior = "own";
        git.sign-on-push = true;
        ui = {
          default-command = "log";
          pager = ":builtin";
          show-cryptographic-signatures = true;
        };
      };
    };
  };

  home.file."${config.programs.git.extraConfig.gpg.ssh.allowedSignersFile}".text = "dzervas@dzervas.gr ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINMUrtMAAGoiU1XOUnw2toDLMKCrhWXPuH8VY9X79IRj Dimitris Zervas";
                       }
