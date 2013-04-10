#!/bin/bash

case $1 in
	install)
		git submodule update --init
		git submodule foreach git pull origin master

		local backup_dir="$HOME/.backup"
		local files=`ls -A --ignore=".git{,modules,ignore}" --ignore=".config"`
		local conf_files=`ls -A .config/`

		for file in $files; do
			if [ [ -f "$HOME/$file" ]  || [ -d "$HOME/$file" ] ] && [ ! -L "$HOME/$file" ] ; then
				echo "$file exists, moving to $backup_dir"
				if [ ! -d $backup_dir ]; then
					mkdir -p $backup_dir
				fi
				mv "$HOME/$file" $backup_dir/
			fi
			ln -s "`pwd`/$file" $HOME/
		done

		for file in $conf_files; do
			if [ [ -f "$HOME/.config/$file" ]  || [ -d "$HOME/.config/$file" ] ] && [ ! -L "$HOME/.config/$file" ] ; then
				echo ".config/$file exists, moving to ${backup_dir}/.config"
				if [ ! -d $backup_dir/.config ]; then
					mkdir -p $backup_dir/.config
				fi
				mv "$HOME/.config/$file" "$backup_dir/.config/"
			fi
			ln -s "`pwd`/.config/$file" $HOME/.config/
		done
		;;
	uninstall)
		echo "You have to do that manually or contribute to this script to make it automatic, you lazy dog!"
		;;
	system)
		echo "Updating system..."
		pacman -Syu
		echo "Installing X.Org server, WM and some other things..."
		pacman -S yajl git gvim xorg-server{,-utils} xorg-xinit ttf-dejavu xterm slim awesome firefox skype xscreensaver
		echo "Instaling yaourt..."
		mkdir -p tmp/{package-query,yaourt}
		cd tmp/package-query
		wget https://aur.archlinux.org/packages/pa/package-query/PKGBUILD
		makepkg --asroot
		pacman -U *xz
		cd ../yaourt
		wget https://aur.archlinux.org/packages/ya/yaourt/PKGBUILD
		makepkg --asroot
		pacman -U *xz
		cd ../..
		echo "Installing Minecraft and minecraft lwjgl fix via AUR"
		yaourt -S minecraft minecraft-updatelwjgl adb
		echo "Enabling Slim on boot"
		systemctl enable slim.service
		systemctl enable xscreensaver.service
		echo "I'm done. TODO:"
		echo "\t- Install graphics driver."
		echo "\t- Configure network."
		echo "\t- Configure slim."
		;;
	*)
		echo "What do you want me to do? Not even an argument!?"
		echo "A logical man would '$0 install' to install the dotfiles or '$0 system' to install all Arch goodies..."
		;;
esac
