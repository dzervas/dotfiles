# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# Variable definitions
	# No duplicates in history
	export HISTCONTROL=ignoredups
	export PS1='\[\e[0;31m\]\u\[\e[m\] \[\e[1;34m\]\w\[\e[m\] \[\e[0;31m\]\$ \[\e[m\]\[\e[0;m\]'
	export EDITOR=vim
	export PATH="~/bin:$PATH:~/.gem/ruby/1.9.1/bin"
	# Check the window size after each command to update LINES and COLUMNS if necessary
	shopt -s checkwinsize

# Alias definitions.
	# remove all *.pyc files in current directory and subdirectories
	alias rmpyc='find . -name "*.pyc" -exec rm -rf {} \;'
	# update all git repos in current dir

	function gitup() {
		for dir in *; do
			if [ -d "$dir/.git" ]; then
				cd $dir
				echo "$dir:"
				git pull
				cd ..
			fi
		done
	}

	# git add all, commit and push
	function gitacp() {
		git ac
		git push
	} 

	# enable color support of ls and also add handy aliases
	if [ "$TERM" != "dumb" ]; then
		eval "`dircolors -b`"
		alias ls='ls --color=auto'
		alias grep='grep --color'
	fi

# Enable completions
	if [ -f /etc/bash_completion ]; then
		. /etc/bash_completion
	fi
	if [ -f ~/.bash-completion/bash_completion ]; then
		. ~/.bash-completion/bash_completion
	fi

# Other useful definitions
	# Make less, more friendly for non-text input files
	[ -x /usr/bin/lesspipe ] && eval "$(lesspipe)"
