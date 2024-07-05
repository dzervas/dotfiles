{ ... }: {
	programs.git = {
    enable = true;
    userName = "Dimitris Zervas";
    userEmail = "dzervas@dzervas.gr";
    aliases = {
      aa = "!git add -A && git status";
      ac = "!git aa && git commit";
      acp = "!git ac && git push";
      bl = "!git reflog show --pretty=format:'%gs ~ %gd' --date=relative | grep 'checkout:' | grep -oE '[^ ]+ ~ .*' | awk -F~ '!seen[$1]++' | head -n 10 | awk -F' ~ HEAD@{' '{printf(\"  \\033[33m%s: \\033[37m %s\\033[0m\\n\", substr($2, 1, length($2)-1), $1)}'";
      c = "clone";
      co = "checkout";
      d = "diff";
      # get-ignore = "!"f(){ curl -L --silent --fail "https://github.com/github/gitignore/raw/main/$1.gitignore" >> .gitignore && echo "Appended to .gitignore" || echo -e "No gitignore found for $1 - check out https://github.com/github/gitignore"; }; f"";
      ll = "log --graph --decorate --abbrev-commit --pretty='%C(auto)%h %d %s %Cgreen(%cr)%Creset [%C(bold blue)%an%Creset %G?]'";
      lla = "log --graph --decorate --abbrev-commit --pretty='%C(auto)%h %d %s %Cgreen(%cr)%Creset [%C(bold blue)%an%Creset  %G?]' --all";
      # Parse positional params
      hub = "!f() { git clone git@github.com:$1; }; f";
      oops = "!echo 'Going to amend and force push. You sure?' && read && git add -A && git commit --amend --no-edit && git push --force-with-lease";
      s = "status";
      undo = "reset HEAD~";
    };
  };
}