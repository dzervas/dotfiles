#!/bin/sh

function github_latest_release() {
	URL=curl -w "%{url_effective}\n" -I -L -s -S "$1" -o /dev/null | sed 's/tag/download/g'
}

cd $HOME
echo "Please install browserpass, ublock, HTTPS everywhere to Firefox"
echo "Installing homebrew..."
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"


echo "Installing shit..."

brew update
brew upgrade
brew tap caskroom/cask caskroom/fonts caskroom/drivers
brew cask install firefox gpg-suite font-iosevka iterm2 karabiner-elements emacs
brew install neovim stow pass wget exa ripgrep git python3 npm \
	pyenv pyenv-virtualenv antigen jq coreutils mtr ag xonsh htop zsh \
	colordiff
# For Arduino: brew cask install arduino ftdi-vcp-driver wch-ch34x-usb-serial-driver

sudo sh -c "echo /usr/local/bin/zsh >> /etc/shells" && chsh -s $(which zsh)

wget https://bootstrap.pypa.io/get-pip.py -O /tmp/get-pip.py
sudo python2 /tmp/get-pip.py
sudo python3 /tmp/get-pip.py


echo "Installing dotfiles"

mkdir Lab
git clone https://github.com/dzervas/dotfiles Lab/dotfiles
stow -d Lab/dotfiles -t . -S bash git vim zsh emacs
ln -s $HOME/.vimrc $HOME/.vim/init.vim
ln -s $HOME/Lab/dotfiles/vim/.vim $HOME/.config/nvim

echo "Setting up Emacs"
sudo pip install rope jedi flake8 autopep8 yapf

echo "Setting up NeoVim"

# TODO: Make PHPcd work
#brew install homebrew/php/php71-pcntl
#sudo mv /usr/local/etc/php/7.1/conf.d/ext-pcntl.ini /usr/local/etc/php/7.1/conf.d/ext-pcntl.ini.b

sudo pip2 install neovim
sudo pip3 install neovim neovim-remote
sudo gem install neovim
sudo npm install -g neovim
pip2 install --user jedi
go get -u github.com/nsf/gocode

nvim -c ":PlugInstall"
nvim -c ":UpdateRemotePlugins"
nvim -c ":GoInstallBinaries"
vim -c ":PlugInstall"
vim -c ":UpdateRemotePlugins"

echo "Installing browserpass"

brew install go
go get -u github.com/dannyvankooten/browserpass/cmd/browserpass
wget https://raw.githubusercontent.com/dannyvankooten/browserpass/master/firefox/host.json -O /tmp/firefox-host.json
sed "s|%%replace%%|$HOME/go/bin/browserpass|g" /tmp/firefox-host.json > $HOME/Library/Application\ Support/Mozilla/NativeMessagingHosts/com.dannyvankooten.browserpass.json


echo "Installing l33t haxxor fonts"


echo "Setting up mac keycodes"
# Found by https://itunes.apple.com/us/app/key-codes/id414568915
