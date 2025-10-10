{ config, pkgs, ... }: {
  # TODO: Somehow integrate [includeIf "hasconfig:remote.*.url:git@github.com:<organisation>/**"] in a safe way

  home.packages = with pkgs; [git-lfs lazyjj];
  programs = rec {
    git = {
      enable = true;
      lfs.enable = true;

      userName = "Dimitris Zervas";
      userEmail = "dzervas@dzervas.gr";
      signing.signByDefault = true;

      difftastic = {
        enable = true;
        options.display = "side-by-side";
        enableAsDifftool = true;
      };

      aliases = {
        aa = "!git add -A && git status";
        ac = "!git aa && git commit";
        acp = ''!f(){ if test $# -gt 0; then git aa && git commit -m "$*" && git push; else git ac && git push; fi }; f'';
        bl = "!git reflog show --pretty=format:'%gs ~ %gd' --date=relative | grep 'checkout:' | grep -oE '[^ ]+ ~ .*' | awk -F~ '!seen[$1]++' | head -n 10 | awk -F' ~ HEAD@{' '{printf(\"  \\033[33m%s: \\033[37m %s\\033[0m\\n\", substr($2, 1, length($2)-1), $1)}'";
        c = "clone";
        co = "checkout";
        d = "diff";
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
        ".devenv"
        ".devenv.flake.nix"
        ".shell.nix"
        ".claude"
        ".claude.json"
        ".mcp.json"
        ".aider.*"
      ];
    };

    gh = {
      enable = true;
      gitCredentialHelper.enable = true;
      extensions = with pkgs; [ gh-copilot ];
      settings = {
        git_protocol = "ssh";
        aliases = {
          co = "pr checkout";
          pv = "pr view";
        };
      };
    };

    jujutsu = {
      enable = true;
      # Workflow cheatsheet:
      # Clone: `jj git clone <url> --colocate` or `jj hub <myrepo>`
      # Migrate existing git repo: `jj git init --colocate`
      # Git branches: `jj bookmark list`
      # Feature branch: `jj new 'trunk()'` (start a change on top of main)
      # Feature branch (update git branch after changes): `jj bookmark create my-new-branch -r @`
      # Commit: `jj commit -m "Hello World"`
      # Push (new branch): `jj git push --allow-new --bookmark my-new-branch`
      # Fetch: `jj git fetch`
      # Rebase on main: `jj rebase -d main@origin`
      # Rebase changes on main: `jj git fetch && jj rebase -b main -d main@origin && jj edit main`
      settings = {
        user = {
          name = git.userName;
          email = git.userEmail;
        };

        aliases = {
          d = ["diff"];
          s = ["status"];
          ll = ["log"];

          acp = [
            "util" "exec" "--" "bash" "-c"
            # push whatever you're on: either the bookmark or just the change itself
            # Using --change @ works even if you didn't name a bookmark yet.
            ''test $# -gt 0 && jj commit -m "$*" || jj commit && jj git push --change @''
          ];
          get-ignore = [
            "util" "exec" "--" "bash" "-c"
            ''curl -fsL "https://www.toptal.com/developers/gitignore/api/$1" >> .gitignore && echo "Appended to .gitignore" || echo "No gitignore found - check out https://gitignore.io"; ''
          ];
          hub = [
            "util" "exec" "--" "bash" "-c"
            ''greq -q / <<< $1 && jj git clone git@github.com:$1 --colocate $2 || jj git clone git@github.com:dzervas/$1 --colocate $2''
          ];
          oops = [
            "util" "exec" "--" "bash" "-c"
            "jj ammend && jj git push --change @"
          ];
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
