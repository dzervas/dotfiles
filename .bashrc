# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# Colors
	NC='\e[0m'       # Text Reset
	
	# Regular Colors
	BLACK='\e[30m'        # Black
	RED='\e[31m'          # Red
	GREEN='\e[32m'        # Green
	YELLOW='\e[33m'       # Yellow
	BLUE='\e[34m'         # Blue
	PURPLE='\e[35m'       # Purple
	CYAN='\e[36m'         # Cyan
	WHITE='\e[37m'        # White
	
	# Bold
	BBLACK='\e[1;30m'       # Black
	BRED='\e[1;31m'         # Red
	BGREEN='\e[1;32m'       # Green
	BYELLOW='\e[1;33m'      # Yellow
	BBLUE='\e[1;34m'        # Blue
	BPURPLE='\e[1;35m'      # Purple
	BCYAN='\e[1;36m'        # Cyan
	BWHITE='\e[1;37m'       # White

# Variable definitions
	# No duplicates in history
	export HISTCONTROL=ignoredups
	export EDITOR=vim
	#export PATH="$PATH:~/.bin"

	# Check the window size after each command to update LINES and COLUMNS if necessary
	shopt -s checkwinsize

# Alias and function definitions.
	# OpenSSL chat server (for more see below)
	function cserv() {
		if [[ -z ${1} ]]; then
			port=9090
		else
			port=${1}
		fi

		echo "Port: ${port}"
		avahi-publish -s "SSL Chat" _https._tcp ${port} &
		cprompt | openssl s_server -quiet -cert ~/.cserv.pem -accept ${port}
	}
	# One extract to rule them all
	function extract () {
		if [ -f $1 ] ; then
			case $1 in
				*.tar.*) tar xf $1 ;;
				*.bz2) bunzip2 $1 ;;
				*.gz) gunzip $1 ;;
				*.rar) rar x $1 ;;
				*.tar) tar xf $1 ;;
				*.tbz2) tar xjf $1 ;;
				*.tgz) tar xzf $1 ;;
				*.zip) unzip $1 ;;
				*.Z) uncompress $1 ;;
				*.7z) 7z x $1 ;;
				*) echo "'$1' cannot be extracted via extract()" ;;
			esac
		else
			echo "'$1' is not a valid file"
		fi
	}

	# git status for command prompt
	function gitstat() {
		if [[ $(git status 2> /dev/null | tail -n1) == \
			'no changes added to commit (use "git add" and/or "git commit -a")' ]]; then
			echo -e "${BWHITE}!"
		elif [[ $(git status 2> /dev/null | grep ahead) != '' ]]; then
			echo -e "${BYELLOW}>>"
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

	# Some useful info for the prompt (background job count & task count)
	function statecnt() {
		job=$(jobs | wc -l)
		to=$(tocnt)

		if [[ $job -ne 0 || $to -ne 0 ]]; then
			echo -en "${GREEN}["

			if [[ $to -ne 0 ]]; then
				echo -en "${YELLOW}T${to}"
			fi

			if [[ $job -ne 0 ]]; then
				if [[ $to -ne 0 ]]; then
					echo -n " "
				fi

				echo -en "${CYAN}J${job}"
			fi

			echo -en "${GREEN}]${NC}"
		else
			return 1
		fi
	}

	eval "`dircolors -b`"

# Alias
	# OpenSSL chat system. For more info do "chelp"
	alias cbrowse='avahi-browse -atr | grep \"SSL Chat\" -A3 | grep = -A3'
	alias cclin='cprompt | openssl s_client -quiet -connect '
	alias chelp='echo "OpenSSL Chat commands:
Network discovery: cbrowse
Client: cclin <ip>:<port>
Server: cserv <port> (requires key in ~/.cserv.pem)
Key generation: openssl req -x509 -nodes -days 365 -newkey rsa:8192 -keyout ~/.cserv.pem -out ~/.cserv.pem"'
	alias cprompt='echo "User ${USER} logged in!"; while true; do
		read tmp
		echo "${USER}: ${tmp}"
	done'

	alias grep='grep --color'
	alias ll='ls -al --color=auto'
	alias ls='ls --color=auto'
	alias man='LC_ALL=C LANG=C man'

	# Beutiful way to show your NIC's IP/MAC address
	alias net='ifconfig | awk "/^[a-z]+[0-9]?/ || /inet/ || /ether/ \
		{ if (\$1 == \"inet\") { print \"\tIP: \" \$2 } else if (\$1 == \"inet6\") \
		{ print \"\tIPv6: \" \$2 } else if (\$1 == \"ether\") \
		{ print \"\tMAC Address: \" \$2 } else { print \"\" \$1 } }"'
	
	# A simple todo list parser
	alias tocnt='grep -s "^\s*+\|^\s*#\|^\s*-" .todo | wc -l'
	alias todo="sed 's/^\s*+.*/$(echo -en ${YELLOW})&/; \
		s/^\s*#.*/$(echo -en ${CYAN})&/; \
		s/^\s*-.*/$(echo -en ${GREEN})&/' .todo 2>/dev/null"

	# Yey! Saved 2 keystrokes! :)
	alias v='vim'

	# 1 line web server
	alias webserver='python -m SimpleHTTPServer'

	# Muscle memory...
	alias :q='exit'

	# Android alias
	if [[ "`uname -m`" == "armv7l" ]]; then
		# Start/Stop android's display manager
		alias stopx='setprop ctl.stop media && setprop ctl.stop zygote && \
			sleep 3 && setprop ctl.stop bootanim'
		alias startx='setprop ctl.start zygote && setprop ctl.start media '

		# Fix vim's size issues on such a small screen
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
	# "You are SSHing" reminder (shutdown the server maybe?)
	if [ -n "$SSH_CLIENT" ]; then
		SSH_COLOR=$RED
		export SSH_INFO="@$RED$(uname -n)"
	else
		SSH_COLOR=$GREEN
	fi

	export PS1="${SSH_COLOR}\u${SSH_INFO} \$(statecnt && echo -n ' ')${BCYAN}\W${GREEN}\$(gitbranch)\$(gitstat)${RED}\$ ${NC}"
