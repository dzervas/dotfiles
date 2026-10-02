# Explicit opt-in: keep the normal Neovim configuration, then load the session UI.
command nvim -c 'lua dofile(vim.fn.expand("~/Lab/dotfiles/pi/fleet/init.lua")).start()' $argv
