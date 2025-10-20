{ config, pkgs, ... }: {
  # TODO: Somehow integrate [includeIf "hasconfig:remote.*.url:git@github.com:<organisation>/**"] in a safe way

  home.packages = with pkgs; [git-lfs gnupg];
  programs = {
    difftastic.options.display = "side-by-side";

    git = {
      enable = true;
      lfs.enable = true;

      settings = {
        alias = {
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

        user = {
          name = "Dimitris Zervas";
          email = "dzervas@dzervas.gr";
        };

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

        difftastic = {
          enable = true;
          enableAsDifftool = true;
        };
      };

      signing.signByDefault = true;

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
        ".jj"
        ".worktrees"
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
      #   commit is essentially: `jj describe && jj new`
      # Push (new branch): `jj git push --allow-new --bookmark my-new-branch`
      # Fetch: `jj git fetch`
      # Rebase on main: `jj rebase -d main@origin`
      # Rebase changes on main: `jj git fetch && jj rebase -b main -d main@origin && jj edit main`
      # Squash (shove the current changes to the parent and create a new change with the same parent): `jj squash`
      # *Delete* a commit: `jj abandon <revset>` - can use <revset>:: to abandon all the children as well
      #   Part of the oplog so undo brings it back
      settings = {
        inherit (config.programs.git.settings) user;

        revset-aliases = {
          "closest_bookmark(to)" = "heads(::to & bookmarks())";
          # Returns the revset that are the remote bookmarks that have `to` as an ancestor (to::) or as a descendant (::to)
          "related_origin_bookmarks(to)" = "remote_bookmarks(remote=origin) & (to:: | ::to)";
          # Return the revs that are after `to` but within a remote bookmark (so ahead)
          "ahead_of_origin(to)" = "related_origin_bookmarks(to)..to";
          # Return the revs that are before `to` but within a remote bookmark (so behind)
          "behind_origin(to)" = "to..related_origin_bookmarks(to)";

          "stash()" = ''bookmarks(glob:"stash/*") | tags(glob:"stash/*") | description(glob:"Stash: *")'';
        };

        aliases = {
          d = ["diff"];
          s = ["status"];
          ll = ["log" "-r" "::"];

          acp = [
            "util" "exec" "--" "bash" "-c"
            ''test $# -gt 0 && jj commit -m "$*" || jj commit && jj push'' ""
          ];
          # Push to a new, auto-generated branch
          # TODO: Allow for named branch
          acp-new = [
            "util" "exec" "--" "bash" "-c"
            ''test $# -gt 0 && jj commit -m "$*" || jj commit && jj git push --change @- --allow-new'' ""
          ];
          get-ignore = [
            "util" "exec" "--" "bash" "-c"
            ''curl -fsL "https://www.toptal.com/developers/gitignore/api/$1" >> .gitignore && echo "Appended to .gitignore" || echo "No gitignore found - check out https://gitignore.io"; '' ""
          ];
          hub = [
            "util" "exec" "--" "bash" "-c"
            ''grep -q / <<< $1 && jj git clone --colocate git@github.com:$1 $2 || jj git clone --colocate git@github.com:dzervas/$1 $2'' ""
          ];
          init = ["git" "init" "--colocate"];
          oops = [
            "util" "exec" "--" "bash" "-c"
            "echo 'Going to squash on immutable and push. You sure?' && read && jj squash --ignore-immutable && jj push"
          ];
          pr = [
            "util" "exec" "--" "bash" "-c"
            ''
              export REVSET=''${1:-'@-'}
              export HEAD_NAME=$(jj log -r "closest_bookmark($REVSET)" -T bookmarks --no-graph --color never)
              [[ $HEAD_NAME == "main" || -z "$HEAD_NAME" ]] && { echo "Cannot create PR for main or unnamed branch"; exit 1; }
              export PR_URL=$(gh pr list -H "$HEAD_NAME" --json url | jq -r 'first.url')

              if [[ "$PR_URL" == "null" ]]; then
                echo "No PR found for $HEAD_NAME, createing..."
                gh pr create --head "$HEAD_NAME" --web
              else
                if [ -t 1 ]; then
                  echo "Opening existing PR for $HEAD_NAME:"
                  echo "$PR_URL"
                  xdg-open "$PR_URL"
                else
                  echo "$PR_URL"
                fi
              fi
            '' ""
          ];
          pull = [
            "util" "exec" "--" "bash" "-c"
            ''test "$(jj log -r @ -T empty --no-graph --color never)" = "true" || echo "Dirty working copy - commit or fetch & new manually" && jj git fetch && jj new "closest_bookmark(@-)"'' ""
          ];
          push = [
            "util" "exec" "--" "bash" "-c"
            "jj tug && jj git push"
          ];
          statuslog = [
            "util" "exec" "--" "bash" "-c"
            "jj status && echo && jj log --limit 5"
          ];
          tug = [ "bookmark" "move" "--from" "closest_bookmark(@-)" "--to" "@-"];
        };

        git = {
          auto-local-bookmark = true;
          sign-on-push = true;
        };

        # Sign all commits owned by us
        signing = {
          behavior = "own";
          backend = "ssh";
          backends.ssh.allowed-signers = config.programs.git.settings.gpg.ssh.allowedSignersFile;
        };
        ui = {
          pager = ":builtin";
          default-command = "statuslog";
          show-cryptographic-signatures = true;
        };
      };
    };
  };

  home.file."${config.programs.git.settings.gpg.ssh.allowedSignersFile}".text = "dzervas@dzervas.gr ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINMUrtMAAGoiU1XOUnw2toDLMKCrhWXPuH8VY9X79IRj Dimitris Zervas";
                       }
