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
	export EDITOR="nvim"
	export ALTERNATE_EDITOR="nvim"
	export HISTCONTROL="ignoredups"
	export HOSTNAME="`hostname`"
	export PAGER="less"
	export PATH="$HOME/.pyenv/bin:$HOME/.bin:$PATH"
	export TZ="Europe/Athens"

	# Check the window size after each command to update LINES and COLUMNS if necessary
	shopt -s checkwinsize

# Alias and function definitions.
	function precmd() {
		print -Pn "\e]0;%n@%m: %~\a"
	}

	# Stack job lister, to get shit together...
	function ++() {
		echo "$(date +'[%d/%m %I:%M]') $@" >> ~/.stack
	}

	function +-() {
		mv ~/.stack{.last,}
	}

	function --() {
		cp ~/.stack{,.last}
		head -n -1 ~/.stack.last > ~/.stack
	}

	function cm() {
		mkdir ${1}
		cd ${1}
	}

	function encthis() {
		tar czf - $1 | gpg -c --cipher-algo aes256 -o $(basename $1)-$(date +%d.%m.%y).tgz.aes
	}

	function decthis() {
		gpg -o- $1 | tar zxvf -
	}

	# Beutiful way to show your NIC's IP/MAC address
	function netstate() {
		ifconfig | awk "/^[a-z]+[0-9]?/ || /inet/ || /ether/ { if (\$1 == \"inet\") { print \"\tIP: \" \$2 } else if (\$1 == \"inet6\") { print \"\tIPv6: \" \$2 } else if (\$1 == \"ether\") { print \"\tMAC Address: \" \$2 } else { print \"\" \$1 } }"
	}

	function sc() {
		count=$(sl | wc -l)
		if (( $count > 0 )); then
			echo -en " $count"
		else
			return 1
		fi
	}

	function sl() {
		datec="\x1b[32m"
		jobc="\x1b[00m"

		sed "s/^\[.*\]/${datec}&${jobc}/" ~/.stack | tac
	}

	function bin2hex() {
		printf '0x%x\n' "$((2#${1}))"
	}

	function hex2bin() {
		echo -ne 0b
		inp=$(echo ${1} | awk '{print toupper($0)}')
		bc <<EOF
ibase=16
obase=2
${inp}
EOF
	}

	# Search CommandLineFU.com via the API
	function cmdfu(){
		curl "http://www.commandlinefu.com/commands/matching/$@/$(echo -n $@ | openssl base64)/plaintext"
	}

	# One extract to rule them all
	function extract () {
		if [ -f $1 ] ; then
			case $1 in
				*.tar.*) tar xf $1 ;;
				*.bz2) bunzip2 $1 ;;
				*.gz) gunzip $1 ;;
				*.rar) unrar x $1 ;;
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
		to=$(todir -c | tr -d "\n")

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

			echo -en "${GREEN}]"
		else
			return 1
		fi
	}

	# Change prompt of remote machine (removes bashrc!)
	function ssh-fix-prompt() {
		command="rm -f ~/.bashrc; sudo sed -i 's/^PS1=.*/PS1=\"\\\e\[${2}m\\\u\@\\\h\\\e\[0m:\\\w\\\$ \"/g' /etc/bash.bashrc"
		if [[ ${3} == "forsure" ]]; then
			ssh -t "${1}" "$command"
		else
			echo "Usage: ${0} <ssh host> <bash color> forsure"
			echo "For colors check: http://misc.flogisoft.com/bash/tip_colors_and_formatting"
			echo "Command (did not execute):"
			echo "$command"
		fi
	}

	eval "`dircolors -b`"

# Alias
	alias busy='my_file=$(find /usr/include -type f | sort -R | head -n 1); my_len=$(wc -l $my_file | awk "{print $1}"); let "r = $RANDOM % $my_len" 2>/dev/null; nvim +$r $my_file'
	alias docker_rm='docker rm $(docker ps --no-trunc -aqf status=exited)'
	alias docker_rmi='docker rmi $(docker images --no-trunc -qf dangling=true)'
	alias webserver='python2 -m SimpleHTTPServer'
	alias passgen='gpg --gen-random --armor 1 '

	alias diff='colordiff -ub'
	alias grep='grep --color'
	alias less='less -R'
	alias ll='ls -hal --color=auto'
	alias ls='ls --color=auto'
	alias man='LC_ALL=C LANG=C man'
	# Come on mutt, we're on 2015...
	alias mutt='TERM=xterm-256color mutt'
	alias pgrep='pgrep -af'
	alias ssh='TERM=xterm-256color ssh'

	# Yey! Saved 2 keystrokes! :)
	alias 8ping='ping 8.8.8.8'
	alias cdt='cd `mktemp -d`'
	alias e='${EDITOR}'
	alias et='${EDITOR} .todir'
	alias es='${EDITOR} ~/.stack'
	alias g='git'
	alias jc='curl -si -H "Content-Type: application/json"'
	alias l='ls --color=auto'
	alias mc='cm'
	alias n='echo -e "\a"; mpg123 -q ~/Music/notification.mp3'
	#alias mc='java -jar .minecraft/minecraft.jar'
	alias py='python'
	alias s='sl'
	alias ss='import /tmp/screenshot.jpg'
	alias ssall='import -window root /tmp/screenshot.jpg'
	alias t='todir'
	alias v='nvim'
	alias vt='nvim .todir'
	alias vs='nvim ~/.stack'

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

	export PS1="${SSH_COLOR}\u${SSH_INFO} \$(statecnt && echo -n ' ')${BCYAN}\W${GREEN}\$(gitbranch)\$(gitstat)${BRED}\$(sc)${RED}\$ ${NC}"

	export ANT_ROOT=/usr/bin/
	export ANDROID_SDK_ROOT=~/.android/sdk
	export ANDROID_HOME=~/.android/sdk
	export NDK_ROOT=~/.android/ndk

	eval "$(pyenv init -)"
	eval "$(pyenv virtualenv-init -)"
