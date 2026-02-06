{ lib, ... }: {
  # All colors from: https://github.com/IlanCosman/tide/blob/main/functions/tide/configure/configs/classic.fish

  programs.starship = {
    enable = true;
    enableTransience = true;
    settings = let
      leftSep = "";
      rightSep = "";

      bgColorHex = "#303030"; # The "main" background color

      sepColor = "fg:#949494 bg:${bgColorHex}";
      frameStyle = "fg:#6C6C6C";
      agentFrameStyle = "fg:#6E56CF";

      leftSepString = "[ ${leftSep} ](${sepColor})";
      rightSepString = "[ ${rightSep} ](${sepColor})";
    in {
      format = lib.concatStrings [
        # TODO: Fix bottom pinning
        # "$\{custom.pin_bottom}"

        # Top left — frame color changes when agentty is active
        "$\{custom.frame_tl}"
        "$\{custom.frame_tl_agent}"
        "[](fg:${bgColorHex})"
        "[ ](bg:${bgColorHex})"

        "$sudo"
        "$direnv"
        "$directory"

        # Agentty info (only visible when active)
        "$\{env_var.AGENTTY_MODE}"
        "$\{env_var.AGENTTY_SESSION}"
        "$\{env_var.AGENTTY_MODEL}"

        "$\{custom.git_branch}"
        "$\{custom.git_status}"
        "$\{custom.git_state}"
        "$\{custom.jj_branch}"
        "$\{custom.jj}"

        "[ ](bg:${bgColorHex})"
        "[](fg:${bgColorHex})"

        "$fill"

        # Top Right
        "[](fg:${bgColorHex})"
        "[ ](bg:${bgColorHex})"

        "$aws"
        "$kubernetes"
        "$python"
        "$time"
        "$jobs"

        "[ ](bg:${bgColorHex})"
        "[](fg:${bgColorHex})"
        "$\{custom.frame_tr}"
        "$\{custom.frame_tr_agent}"
        "\n" # Prompt line

        # Prompt line
        "$\{custom.frame_bl}"
        "$\{custom.frame_bl_agent}"
        "$character"
      ];

      right_format = lib.concatStrings [
        "$cmd_duration"
        "$\{env_var.IN_NIX_SHELL}"
        "$\{custom.frame_br}"
        "$\{custom.frame_br_agent}"
      ];

      sudo = {
        disabled = false;
        format = "[$symbol]($style)";
        symbol = " ";
        style = "bg:${bgColorHex} bold yellow";
      };

      env_var.IN_NIX_SHELL = {
        format = "[$symbol$env_value]($style)";
        style = "fg:#00AFFF";
        symbol = "󱄅 ";
      };

      # Agentty env_var modules — only render when the var is set
      env_var.AGENTTY_MODE = {
        format = "[${leftSepString} 󱞁 $env_value ](fg:#F6C177 bg:${bgColorHex})";
      };

      env_var.AGENTTY_SESSION = {
        format = "[ 󰉖 $env_value ](fg:#C4A7E7 bg:${bgColorHex})";
      };

      env_var.AGENTTY_MODEL = {
        format = "[ 󰘦 $env_value ](fg:#9CCFD8 bg:${bgColorHex})";
      };

      direnv = {
        disabled = false;
        style = "fg:#00AFFF bg:${bgColorHex}";
        format = "[$symbol$loaded ]($style)";
        symbol = " ";
        loaded_msg = "";
        unloaded_msg = "✘ ";
      };

      directory = {
        style = "fg:#00AFFF bg:${bgColorHex}";
        read_only_style = "fg:#e3e5e5 bg:${bgColorHex}";
        read_only = "󰌾 ";
        format = "[$path]($style)";

        truncate_to_repo = false;
        truncation_length = 3;
        truncation_symbol = "󰇘/";

        substitutions = {
          Documents = "󰈙 ";
          Downloads = " ";
          Music = " ";
          Pictures = " ";
          "Lab/dotfiles" = "󱄅 ";
        };
      };

      jobs = {
        format = "[ $symbol( $number)]($style)";
        style = "bg:${bgColorHex} bold blue";
        symbol = "󰒲 ";
      };

      aws = {
        # TODO: Profile & region alias? https://starship.rs/config/#aws
        format = "[$symbol$profile${rightSepString}]($style)";
        style = "bg:#303030 bold orange";
        symbol = " ";
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

      git_branch = {
        style = "fg:#5FD700 bg:${bgColorHex}";
        format = "${leftSepString}[$branch]($style)";
        disabled = true;
      };

      git_status = {
        style = "fg:#D7AF00 bg:${bgColorHex}";
        format = "[$all_status$ahead_behind]($style)";

        ahead = "  $count";
        behind = "  $count";
        conflicted = " [ $count](fg:#FF0000 bg:${bgColorHex})";
        deleted = " ✘ $count";
        modified = " !$count";
        renamed = "  $count";
        staged = " +$count";
        stashed = " [*$count](fg:#5FD700 bg:${bgColorHex})";
        untracked = " ?$count";

        disabled = true;
      };

      git_state = {
        style = "fg:#FF0000 bg:${bgColorHex}";

        disabled = true;
      };

      custom = let
        # TODO: Find a faster way to understand if this is a jj repo
        is-jj-repo = "jj --ignore-working-copy root";
        jj-args = "--ignore-working-copy --color never --no-graph";
      in {
        # Frame modules — normal (when AGENTTY_ACTIVE is not set)
        frame_tl = {
          command = "printf '╭─'";
          format = "[$output](${frameStyle})";
          when = "test -z \"$AGENTTY_ACTIVE\"";
          shell = ["bash"];
        };
        frame_tr = {
          command = "printf '─╮'";
          format = "[$output](${frameStyle})";
          when = "test -z \"$AGENTTY_ACTIVE\"";
          shell = ["bash"];
        };
        frame_bl = {
          command = "printf '╰─'";
          format = "[$output](${frameStyle})";
          when = "test -z \"$AGENTTY_ACTIVE\"";
          shell = ["bash"];
        };
        frame_br = {
          command = "printf '─╯'";
          format = "[$output](${frameStyle})";
          when = "test -z \"$AGENTTY_ACTIVE\"";
          shell = ["bash"];
        };

        # Frame modules — agent mode (purple when AGENTTY_ACTIVE is set)
        frame_tl_agent = {
          command = "printf '╭─'";
          format = "[$output](${agentFrameStyle})";
          when = "test -n \"$AGENTTY_ACTIVE\"";
          shell = ["bash"];
        };
        frame_tr_agent = {
          command = "printf '─╮'";
          format = "[$output](${agentFrameStyle})";
          when = "test -n \"$AGENTTY_ACTIVE\"";
          shell = ["bash"];
        };
        frame_bl_agent = {
          command = "printf '╰─'";
          format = "[$output](${agentFrameStyle})";
          when = "test -n \"$AGENTTY_ACTIVE\"";
          shell = ["bash"];
        };
        frame_br_agent = {
          command = "printf '─╯'";
          format = "[$output](${agentFrameStyle})";
          when = "test -n \"$AGENTTY_ACTIVE\"";
          shell = ["bash"];
        };

        jj_branch = {
          # TODO: Show ahead/behind - use the `ahead_of_origin` and `behind_origin` revsets

          # Show the closest bookmark (branch) to the current change
          command = ''jj log ${jj-args} -r 'closest_bookmark(@-)' --template 'bookmarks.join("/")' '';
          format = "${leftSepString}[󰠬 ](bg:${bgColorHex})[$output ]($style)";
          style = "fg:#5FD700 bg:${bgColorHex}";
          when = is-jj-repo;
        };

        # State & status equivalent of git
        jj = let
          status-map = {
            added = "+";
            removed = "✘ ";
            modified = "!";
            renamed = " ";
            copied = " ";
          };
          diff-status = status: ''diff.files().filter(|e| e.status()=="${status}")'';
          status-checks = lib.mapAttrsToList (status: icon: ''if(${diff-status status}, "${icon}" ++ ${diff-status status}.len())'') status-map;
          status-line = builtins.concatStringsSep ", " status-checks;
        in {
          command = ''jj log ${jj-args} -n1 -r@  --template '
            separate(" ",
              ${status-line},
              if(conflict, " "),
              if(divergent, "⇕ "),
              if(hidden, "󰘓 "),
              surround("\"", "\"", truncate_end(24, description.first_line(), "…")),
            )' '';
          format = "[$output]($style)";
          style = "fg:#D7AF00 bg:${bgColorHex}";
          when = is-jj-repo;
        };

        # git fallback
        git_branch = {
          when = "! ${is-jj-repo}";
          format = "$output";
          command = "starship module git_branch";
        };
        git_status = {
          when = "! ${is-jj-repo}";
          format = "$output";
          command = "starship module git_status";
        };
        git_state = {
          when = "! ${is-jj-repo}";
          format = "$output";
          command = "starship module git_state";
        };

        # pin_bottom = {
        #   command = "tput cup $COLUMNS 1";
        #   format = "$output";
        #   when = true;
        # };
      };
    };
  };
}
