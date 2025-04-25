-- Source system vimrc
vim.cmd("source /etc/vimrc")

-- Set viminfo to default
vim.cmd("set viminfo&")

-- Airline configuration
vim.g.airline_powerline_fonts = 1
vim.g.airline_theme = "badwolf"
vim.g.airline_extensions_syntastic_enabled = 1
vim.g.airline_extensions_hunks_non_zero_only = 0

-- NERDCommenter configuration
vim.g.NERDSpaceDelims = 1
vim.g.NERDTrimTrailingWhitespace = 1
vim.keymap.set('n', '<C-/>', '<Plug>NERDCommenterToggle')
vim.keymap.set('v', '<C-/>', '<Plug>NERDCommenterToggle<CR>gv')

-- Auto close preview window
-- vim.api.nvim_create_autocmd("InsertLeave", {
  -- pattern = "*",
  -- callback = function()
    -- if vim.fn.pumvisible() == 0 then
      -- vim.cmd("pclose")
    -- end
  -- end
-- })

-- Move plugin configuration
vim.g.move_map_keys = 0
vim.keymap.set('n', '<C-up>', '<Plug>MoveLineUp')
vim.keymap.set('n', '<C-down>', '<Plug>MoveLineDown')
vim.keymap.set('v', '<C-up>', '<Plug>MoveBlockUp')
vim.keymap.set('v', '<C-down>', '<Plug>MoveBlockDown')

-- Suda configuration for sudo operations
vim.g.suda_smart_edit = 1
vim.cmd("cnoremap e! SudaRead")
vim.cmd("cnoremap w! SudaWrite")

-- Terminal configuration
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "*",
  command = "startinsert"
})

-- Rebuild command
vim.api.nvim_create_user_command("Rebuild", "belowright 10split term://rebuild", {})

-- Reload configuration
vim.keymap.set('n', '<A-R>', function()
  vim.cmd("source ~/.config/nvim/init.lua")
  print("Reloaded!")
end)

-- AI/Copilot configuration
vim.g.copilot_enabled = false
vim.keymap.set('n', '<leader>c', function()
  vim.cmd("Copilot enable")
  print("Copilot Enabled")
end)
