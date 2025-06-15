{ lib, ... }: {
  # All colors from: https://github.com/IlanCosman/tide/blob/main/functions/tide/configure/configs/classic.fish

  programs.starship = {
    enable = true;
    enableTransience = true;
    settings = let
      leftSep = "";
      rightSep = "";

      bgColorHex = "#303030"; # The "main" background color

      sepColor = "fg:#949494 bg:${bgColorHex}";
      frameStyle = "fg:#6C6C6C";

      leftSepString = "[ ${leftSep} ](${sepColor})";
      rightSepString = "[ ${rightSep} ](${sepColor})";
    in {
      format = lib.concatStrings [
        # Top left
        "[╭─](${frameStyle})"
        "[](fg:${bgColorHex})"
        # "[ ](bg:${bgColorHex})"

        "$sudo"
        "$direnv"
        "$directory"
        "$git_branch"
        "$git_status"
        "$git_state"

        "[](fg:${bgColorHex})"

        "$fill"

        # Top Right
        "[](fg:${bgColorHex})"
        "[ ](bg:${bgColorHex})"

        "$jobs"
        "$aws"
        "$kubernetes"
        "$python"
        "$time"

        "[ ](bg:${bgColorHex})"
        "[](fg:${bgColorHex})"
        "[─╮](${frameStyle})"
        "\n" # Prompt line

        # Prompt line
        "[╰─](${frameStyle})"
        "$character"
      ];

      right_format = lib.concatStrings [
        "$cmd_duration"
        "$\{env_var.IN_NIX_SHELL}"
        "[─╯](${frameStyle})"
      ];

      sudo = {
        disabled = false;
        format = "[$symbol]($style)";
        symbol = " ";
        style = "bg:${bgColorHex} bold yellow";
      };

      env_var.IN_NIX_SHELL = {
        format = "[$symbol$env_value]($style)";
        style = "fg:#00AFFF";
        symbol = "󱄅 ";
      };

      direnv = {
        disabled = false;
        style = "fg:#00AFFF bg:${bgColorHex}";
        format = "[ $symbol$loaded]($style)";
        symbol = "";
        loaded_msg = "";
        unloaded_msg = " ✘";
      };

      directory = {
        style = "fg:#00AFFF bg:${bgColorHex}";
        read_only_style = "fg:#e3e5e5 bg:${bgColorHex}";
        read_only = "󰌾 ";
        format = "[ $path]($style)";

        truncate_to_repo = false;
        truncation_length = 3;
        truncation_symbol = "󰇘/";

        substitutions = {
          Documents = "󰈙 ";
          Downloads = " ";
          Music = " ";
          Pictures = " ";
          "Lab/dotfiles" = "󱄅 ";
        };
      };

      git_branch = {
        style = "fg:#5FD700 bg:${bgColorHex}";
        format = "${leftSepString}[$branch]($style)";
      };

      git_status = {
        style = "fg:#D7AF00 bg:${bgColorHex}";
        format = "[$all_status$ahead_behind ]($style)";

        ahead = "  $count";
        behind = "  $count";
        conflicted = " [ $count](fg:#FF0000 bg:${bgColorHex})";
        deleted = " ✘ $count";
        modified = " !$count";
        renamed = "  $count";
        staged = " +$count";
        stashed = " [*$count](fg:#5FD700 bg:${bgColorHex})";
        untracked = " ?$count";
      };

      git_state = {
        style = "fg:#FF0000 bg:${bgColorHex}";
      };

      jobs = {
        format = "[$symbol( $number)]($style)";
        style = "bg:${bgColorHex} bold blue";
      };

      aws = {
        # TODO: Profile & region alias? https://starship.rs/config/#aws
        format = "[$symbol$profile${rightSepString}]($style)";
        style = "bg:#303030 bold orange";
        symbol = " ";
        expiration_symbol = "󰌾 ";
      };

      kubernetes = {
        disabled = false;
        format = "[$symbol$context/$namespace${rightSepString}]($style)";
        style = "fg:#326CE5 bg:${bgColorHex}";
        symbol = "󱃾 ";
      };

      python = {
        style = "green bg:${bgColorHex}";
        symbol = "󱔎 ";
        format = "[($symbol@$virtualenv${rightSepString})]($style)";
      };

      time = {
        disabled = false;
        time_format = "%R"; # Hour:Minute Format
        style = "fg:#5F8787 bg:${bgColorHex} bold";
        format = "[$time]($style)";
      };

      fill = {
        symbol = "·";
        style = frameStyle;
      };
    };
  };
}
