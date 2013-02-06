#!/bin/bash

case $1 in
	install)
		export backup_dir="$HOME/.backup"
		export files=`ls -A --ignore=".git{,modules,ignore}" --ignore=".config"`
		export conf_files=`ls -A .config/`
		# TODO: create proper symlinks of ~/.config
		for file in $files; do
			if [ -f "$HOME/$file" ]  || [ -d "$HOME/$file" ] && [ ! -L "$HOME/$file" ]  ; then
				echo "$file exists, moving to $backup_dir"
				if [ ! -d $backup_dir ]; then
					mkdir -p $backup_dir
				fi
				mv "$HOME/$file" $backup_dir/
			fi
			ln -s "`pwd`/$file" $HOME/
		done
		
		ln -s .config/???* "$HOME/.config/"
		git submodule update --init
		git submodule foreach git pull origin master
		;;
	uninstall)
		echo "You have to do that manually, or contribute to this script. Lazy dog."
		;;
	system)
		echo "Updating system..."
		pacman -Syu
		echo "Installing X.Org server, WM and some other things..."
		pacman -S yajl git vim xorg-server{,-utils} xorg-xinit mesa ttf-dejavu xterm slim awesome firefox skype
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
		echo "Installing Technic Launcher via AUR"
		yaourt -S tekkit
		echo "Enabling Slim on boot"
		systemctl enable slim.service
		echo "I'm done. Install the appropriate graphics driver and then reboot."
		;;
	*)
		echo "What do you want me to do? Not even an argument!?"
		echo "A logical man would '$0 install' to install the dotfiles or '$0 system' to install all Arch goodies..."
		;;
esac
