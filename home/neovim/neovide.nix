{ config, lib, ... }:
{
  programs.neovide = {
    enable = true;
    settings = {
      "font.normal" = [ config.stylix.fonts.monospace.name ];
      "font.size" = 14.0;
    };
  };

  programs.nixvim.extraConfigLuaPost = lib.mkAfter ''
    if vim.g.neovide then
      vim.g.neovide_cursor_animation_length = 0
      vim.g.neovide_scroll_animation_far_lines = 3
      vim.g.neovide_normal_opacity = 0.87

      vim.keymap.set({ "n", "v", "s", "x", "o", "i", "l", "c", "t" }, "<C-S-V>", function() vim.api.nvim_paste(vim.fn.getreg('+'), true, -1) end, { desc = "Copy system clipboard", noremap = true, silent = true })

      vim.api.nvim_set_keymap("n", "<C-+>", ":lua vim.g.neovide_scale_factor = vim.g.neovide_scale_factor + 0.1<CR>", { silent = true })
      vim.api.nvim_set_keymap("n", "<C-->", ":lua vim.g.neovide_scale_factor = vim.g.neovide_scale_factor - 0.1<CR>", { silent = true })
      vim.api.nvim_set_keymap("n", "<C-0>", ":lua vim.g.neovide_scale_factor = 1<CR>", { silent = true })
    end
  '';
}
