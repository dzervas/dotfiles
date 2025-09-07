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
      vim.g.neovide_normal_opacity = 0.9

      vim.keymap.set({ "x" }, "<C-S-C>", '"+y', { desc = "Copy system clipboard" })
      vim.keymap.set({ "x" }, "<C-S-V>", '"+p', { desc = "Paste system clipboard" })
    end
  '';
}
