#!/bin/sh
sudo pacman -Syu --needed base base-devel wget git vim stow zsh python2-pip python-pip go htop rofi xautolock

usermod -s /bin/zsh $(USER)

git clone https://aur.archlinux.org/trizen
cd trizen
makepkg -si
cd ..
rm -rf trizen

trizen -S --needed emacs ripgrep lsd neovim xorg i3 polybar antigen-git bat fzf browserpass

mkdir Lab
git clone https://github.com/dzervas/dotfiles Lab/dotfiles
stow -d Lab/dotfiles -t . -S bash git vim zsh emacs
ln -s $HOME/.vimrc $HOME/.vim/init.vim
ln -s $HOME/Lab/dotfiles/vim/.vim $HOME/.config/nvim

echo "Setting up Emacs"
pip install --user rope jedi flake8 autopep8 yapf

echo "Setting up NeoVim"
pip2 install --user neovim jedi
pip3 install --user neovim neovim-remote
gem install neovim
npm install -g neovim
go get -u github.com/nsf/gocode

nvim -c ":PlugInstall"
nvim -c ":UpdateRemotePlugins"
nvim -c ":GoInstallBinaries"
vim -c ":PlugInstall"
vim -c ":UpdateRemotePlugins"

echo "Installing browserpass"

go get -u github.com/dannyvankooten/browserpass/cmd/browserpass
wget https://raw.githubusercontent.com/dannyvankooten/browserpass/master/firefox/host.json -O $HOME/Library/Application\ Support/Mozilla/NativeMessagingHosts/com.dannyvankooten.browserpass.json
sed -i "s|%%replace%%|$HOME/go/bin/browserpass|g" $HOME/Library/Application\ Support/Mozilla/NativeMessagingHosts/com.dannyvankooten.browserpass.json
