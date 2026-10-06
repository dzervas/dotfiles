{ inputs, pkgs, ... }:
let
  inherit (inputs.nixvim.lib.nixvim) utils;
in
{
  # Zed-like formatting: conform runs the formatters on save, with the language
  # server as a fallback. Diagnostics and code actions stay in none-ls (lint.nix).
  programs.nixvim.plugins.conform-nvim = {
    enable = true;

    # Conform's formatter names map to nixpkgs packages. The custom nix formatter
    # is defined in this repo (see overlays/compact-nix.nix).
    autoInstall = {
      enable = true;
      overrides = { compact-nix = pkgs.compact-nix; };
    };

    settings = {
      format_on_save = {
        lsp_format = "fallback";
        timeout_ms = 1000;
      };

      # Conform has no built-in for our script, so define it: conform feeds the
      # buffer on stdin and reads the result on stdout
      formatters.compact-nix = {
        command = "compact-nix";
        stdin = true;
      };

      formatters_by_ft = {
        bash = [ "shellharden" "shfmt" ];
        classnames = [ "rustywind" ]; # Tailwind classes
        fish = [ "fish_indent" ];
        go = [ "goimports" "gofmt" ];
        hcl = [ "hcl" ];
        lua = [ "stylua" ];
        # nixfmt followed by the compact-style pass, so the repo's style survives
        nix = [ "compact-nix" ];
        python = [ "isort" "black" ];
        sh = [ "shellharden" "shfmt" ];
        terraform = [ "terraform_fmt" ];
      };
    };
  };

  programs.nixvim.keymaps = [
    {
      key = "<leader>w";
      action = utils.mkRaw "function() require('conform').format({ lsp_format = 'fallback' }) end";
      options.desc = "Format the current file";
    }
  ];
}
