{ pkgs, ... }: {
  programs.nixvim.plugins = {
    none-ls = {
      enable = true;

      # Check https://github.com/nvimtools/none-ls.nvim/blob/main/doc/BUILTINS.md
      sources = {
        code_actions = {
          gitrebase.enable = true;
          gitsigns.enable = true;
          gomodifytags.enable = true;
          impl.enable = true;
          # refactoring.enable = true; # Does not support rust and needs a binary?
          statix.enable = true;
          # ts_node_action.enable = true; # Tree sitter - can't find the binary?
        };
        # No completion, it's taken care of by blink-cmp
        diagnostics = {
          actionlint.enable = true;
          ansiblelint.enable = true;
          checkmake.enable = true;
          deadnix.enable = true;
          dotenv_linter.enable = true;
          fish.enable = true;
          ltrs.enable = true; # Rust
          # opentofu_validate.enable = true; # Fights with terraform_validate
          pylint.enable = true;
          revive.enable = true; # Golang
          selene.enable = true; # Lua
          sqruff.enable = true; # SQL
          statix.enable = true;
          terraform_validate.enable = true;
          terragrunt_validate.enable = true;
          tfsec.enable = true;
          tidy.enable = true; # HTML & XML
          todo_comments.enable = true; # todo comments - is it good?
          trivy.enable = true; # Terraform vulns
          yamllint = {
            enable = true;
            settings = {
              extra_args = [
                "-d"
                (builtins.toJSON {
                  extends = "default";
                  rules.line-length = "disable";
                })
              ];
              extra_filetypes = ["toml"];
            };
          };
        };
        formatting = {
          # alejandra.enable = true; # Nix - nixfmt instead
          # biome.enable = true; # HTML/CSS/JS/TS/JSON
          black.enable = true; # Python
          fish_indent.enable = true;
          gofmt.enable = true;
          goimports.enable = true;
          goimports_reviser.enable = true; # Does it need goimports too?
          hclfmt.enable = true;
          isort.enable = true; # Python imports sorter
          nixfmt = {
            enable = true;
            package = pkgs.nixfmt-rfc-style;
          };
          # opentofu_fmt.enable = true;
          prettier.enable = true; # HTML/CSS/JS/TS/JSON/Astro
          rustywind.enable = true; # Tailwind classes
          shellharden.enable = true;
          shfmt.enable = true;
          stylua.enable = true;
          terraform_fmt.enable = true;
          terragrunt_fmt.enable = true;
          tidy.enable = true; # HTML & XML
          yamlfix.enable = true;
        };
      };
    };
  };
}
