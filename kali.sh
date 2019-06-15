apt-get update
apt-get install zsh neovim zsh-antigen emacs ripgrep fzf fd-find cargo i3 gnome-screenshot
pip3 install rope jedi flake8 autopep8 yapf neovim neovim-remote
pip2 install neovim jedi
cargo install bat lsd

git clone https://github.com/polybar/polybar
cd polybar/
apt-get install cmake cmake-data libcairo2-dev libxcb1-dev libxcb-ewmh-dev libxcb-icccm4-dev libxcb-image0-dev libxcb-randr0-dev libxcb-util0-dev libxcb-xkb-dev pkg-config python-xcbgen xcb-proto libxcb-xrm-dev libasound2-dev libmpdclient-dev libiw-dev libcurl4-openssl-dev libpulse-dev libxcb-composite0-dev unifont kitty
./build.sh

apt-get install git g++ libgtk-3-dev gtk-doc-tools gnutls-bin valac intltool libpcre2-dev libglib3.0-cil-dev libgnutls28-dev libgirepository1.0-dev libxml2-utils gperf libgtk-3-dev
git clone --recursive https://github.com/thestinger/termite.git
git clone https://github.com/thestinger/vte-ng.git

export LIBRARY_PATH=/usr/include/gtk-3.0:/usr/include/gtk-3.0:/usr/include/gtk-3.0:
cd vte-ng && ./autogen.sh && make && make install && cd ..
cd termite && make && make install && cd ..
ldconfig
ln -s /root/dotfiles/vim/.vim /root/.config/nvim

echo "Install Iosevka Term by hand!"
