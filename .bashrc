# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# Colors
	NC='\e[0m'       # Text Reset
	
	# Regular Colors
	Black='\e[0;30m'        # Black
	Red='\e[0;31m'          # Red
	Green='\e[0;32m'        # Green
	Yellow='\e[0;33m'       # Yellow
	Blue='\e[0;34m'         # Blue
	Purple='\e[0;35m'       # Purple
	Cyan='\e[0;36m'         # Cyan
	White='\e[0;37m'        # White
	
	# Bold
	BBlack='\e[1;30m'       # Black
	BRed='\e[1;31m'         # Red
	BGreen='\e[1;32m'       # Green
	BYellow='\e[1;33m'      # Yellow
	BBlue='\e[1;34m'        # Blue
	BPurple='\e[1;35m'      # Purple
	BCyan='\e[1;36m'        # Cyan
	BWhite='\e[1;37m'       # White

# Variable definitions
	# No duplicates in history
	export HISTCONTROL=ignoredups
	export EDITOR=vim
	export PATH="$PATH:~/bin"
	# Check the window size after each command to update LINES and COLUMNS if necessary
	shopt -s checkwinsize

# Alias and function definitions.
	# remove all *.pyc files in current directory and subdirectories
	alias rmpyc='find . -name "*.pyc" -exec rm -rf {} \;'

	# git status for command prompt
	function gitstat() {
		if [[ $(git status 2> /dev/null | tail -n1) == 'no changes added to commit (use "git add" and/or "git commit -a")' ]]; then
			echo -e "${BWhite}!"
		elif [[ $(git status 2> /dev/null | grep ahead) != '' ]]; then
			echo -e "${BYellow}>>"
		fi
	}

	# git branch for command prompt
	function gitbranch() {
		branch=`git rev-parse --abbrev-ref HEAD 2>/dev/null`
		[ ! -z $branch ] && echo " $branch"
	}

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

	# execute a command for x seconds
	# use: timealarm <seconds> <command> [args...]
	timealarm () {
		perl -e 'alarm shift; exec @ARGV' "$@";
	}

	# Prepare the environment for ARM cross compilation
	cc-arm-kernel() {
		export PATH=$PATH:/opt/arm-linux-androideabi-4.6/bin
		export ARCH=arm
		export SUBARCH=arm
		export CROSS_COMPILER=arm-linux-androideabi-
	}


	# enable color support of ls and also add handy aliases
	if [[ "$TERM" != "dumb" ]]; then
		eval "`dircolors -b`"
		alias ls='ls --color=auto'
		alias grep='grep --color'
	fi

	if [[ "`uname -m`" == "armv7l" ]]; then
		alias stopx='setprop ctl.stop media && setprop ctl.stop zygote && sleep 3 && setprop ctl.stop bootanim'
		alias startx='setprop ctl.start zygote && setprop ctl.start media '
		alias fixterm='stty rows 81 cols 320'
	fi

# Enable completions
	if [[ `shopt` == `false` ]]; then
		return
	fi

	if [ -f /etc/bash_completion ]; then
		. /etc/bash_completion
	fi
	if [ -f ~/.bash-completion/bash_completion ]; then
		. ~/.bash-completion/bash_completion
	fi

# Other useful definitions
	export PS1="${Red}\u ${BBlue}\W${Green}\$(gitbranch)\$(gitstat)${Red}\$ ${NC}"
