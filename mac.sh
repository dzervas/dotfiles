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
brew tap caskroom/fonts caskroom/drivers
brew cask install firefox gpg-suite font-iosevka iterm2
brew install neovim stow pass wget exa ripgrep git python3 npm pyenv pyenv-virtualenv antigen jq coreutils mtr
# For Arduino: brew cask install arduino ftdi-vcp-driver wch-ch34x-usb-serial-driver

chsh -s $(which zsh)

wget https://bootstrap.pypa.io/get-pip.py -O /tmp/get-pip.py
sudo python /get-pip.py


echo "Installing dotfiles"

git clone git@github.com:dzervas/dotfiles Lab/dotfiles
stow -d Lab/dotfiles -t . -S bash git vim zsh
ln -s $HOME/.vimrc $HOME/.vim/init.vim
ln -s $HOME/Lab/dotfiles/vim/.vim $HOME/.config/nvim


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


echo "Installing gonvim"

brew install qt5

export QT_HOMEBREW=true
export QT_DIR=$HOME/.qt5
mkdir $QT_DIR
github_latest_release "https://github.com/dzhou121/gonvim/releases/latest"
wget "$URL/gonvim-macos.zip" -O /tmp/gonvim.zip
unzip /tmp/gonvim.zip -d /Applications/


echo "Setting up mac keycodes"
# Found by https://itunes.apple.com/us/app/key-codes/id414568915
