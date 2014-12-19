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

	# Check the window size after each command to update LINES and COLUMNS if necessary
	shopt -s checkwinsize

# Alias and function definitions.
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

	alias ll='ls -al --color=auto'
	alias man='LC_ALL=C LANG=C man'


	alias cbrowse='avahi-browse -atr | grep "SSL Chat" -A3 | grep = -A3'
	alias cprompt='echo "User ${USER} logged in!"; while true; do
	read tmp
	echo "${USER}: ${tmp}"
done'
	# Called with "cclin <ip>:<port>"
	alias cclin='cprompt | openssl s_client -quiet -connect '
	# Called with "cserv <port>"
	# Needs .cserv.pem generated with:
	# openssl req -x509 -nodes -days 365 -newkey rsa:8192 -keyout ~/.cserv.pem -out ~/.cserv.pem
	alias cserv='avahi-publish -s "SSL Chat" _https._tcp 8080 & ; cprompt | openssl s_server -quiet -cert ~/.cserv.pem -accept '
	alias chelp='echo "Usage: cclin <ip>:<port>, cserv <port>
Key generation: openssl req -x509 -nodes -days 365 -newkey rsa:8192 -keyout ~/.cserv.pem -out ~/.cserv.pem"'

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

# Other useful definitions
	if [ -n "$SSH_CLIENT" ]; then
		SSH_COLOR=$Red
		export SSH_INFO="@$Red$(uname -n)"
	else
		SSH_COLOR=$Green
	fi
	export PS1="${SSH_COLOR}\u${SSH_INFO} ${BBlue}\W${Green}\$(gitbranch)\$(gitstat)${Red}\$ ${NC}"
