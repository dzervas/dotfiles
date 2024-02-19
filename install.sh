#!/bin/sh
# GitHub Codespaces installation file - https://docs.github.com/en/codespaces/setting-your-user-preferences/personalizing-github-codespaces-for-your-account#dotfiles

sudo apt-get update
sudo apt-get install -y stow git

rm ~/.bashrc ~/.zshrc
stow -S -t ~ shell

sudo apt-get install -y bat colordiff ripgrep fd-find fzf python3-argcomplete pipx #lsd

# Ubuntu packaging shenanigans
sudo ln -s /usr/bin/batcat /usr/bin/bat
sudo ln -s /usr/bin/fdfind /usr/bin/fd
sudo ln -s /usr/bin/register-python-argcomplete3 /usr/bin/register-python-argcomplete

curl https://pyenv.run | bash
curl -L git.io/antigen > ~/.antigen.zsh

# Git stuff
git config --global --remove-section user
git config --global --remove-section gpg
git config --global --remove-section gpg.ssh
