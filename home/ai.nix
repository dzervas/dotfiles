{ inputs, pkgs, ... }: {
  home.packages = with pkgs; [
    inputs.claude-desktop.packages.${pkgs.system}.claude-desktop-with-fhs
    cursor-cli
    codex
  ];

  programs.claude-code = {
    enable = true;
    settings = {
      model = "opusplan";
      enableAllProjectMcpServers = false;
      includeCoAuthoredBy = false;
      statusLine = {
        command = "input=$(cat); echo \"[$(echo \"$input\" | jq -r '.model.display_name')] 📁 $(basename \"$(echo \"$input\" | jq -r '.workspace.current_dir')\")\"";
        padding = 0;
        type = "command";
      };

      permissions = {
        defaultMode = "acceptEdits";
        disableBypassPermissionsMode = "disable";
        # additionalDirectories = [];

        allow = [
          "Bash(cargo check:*)"
          "Bash(cargo build:*)"
          "Bash(cargo test:*)"
          "Bash(git diff:*)"
          "Bash(hurl:*)"
          "Bash(nix run .)"
          "Bash(yarn test)"

          "WebSearch"
          "WebFetch(domain:hurl.dev)"
        ];
        ask = [
          "Bash(git commit:*)"
          "Bash(git push:*)"
        ];
        deny = [
          "Read(./.env)"
          "Read(./.envrc)"
          "Read(./.direnv)"
        ];
      };
    };
  };
}
