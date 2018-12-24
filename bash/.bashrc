# If not running interactively, don't do anything
[ -z "$PS1" ] && return
if [[ $(tty) == "/dev/tty1" ]]; then
	export XKB_DEFAULT_LAYOUT=us,gr
	export XKB_DEFAULT_OPTIONS=caps:escape,grp:win_space_toggle
	sway
	exit 0
fi

# Colors
	NC='\e[0m'       # Text Reset
	
	# Regular Colors
	export BLACK='\e[30m'        # Black
	export RED='\e[31m'          # Red
	export GREEN='\e[32m'        # Green
	export YELLOW='\e[33m'       # Yellow
	export BLUE='\e[34m'         # Blue
	export PURPLE='\e[35m'       # Purple
	export CYAN='\e[36m'         # Cyan
	export WHITE='\e[37m'        # White
	
	# Bold
	export BBLACK='\e[1;30m'       # Black
	export BRED='\e[1;31m'         # Red
	export BGREEN='\e[1;32m'       # Green
	export BYELLOW='\e[1;33m'      # Yellow
	export BBLUE='\e[1;34m'        # Blue
	export BPURPLE='\e[1;35m'      # Purple
	export BCYAN='\e[1;36m'        # Cyan
	export BWHITE='\e[1;37m'       # White

# Variable definitions
	# No duplicates in history
	export ALTERNATE_EDITOR="vim"
	export EDITOR="nvr --remote-wait-silent"
	export HISTCONTROL="ignoredups"
	export HOSTNAME=$(hostname)
	export MANPATH="$MANPATH:$NPM_PACKAGES/share/man"
	export NPM_PACKAGES="${HOME}/.npm-packages"
	export PAGER="less"
	#export PATH="$HOME/.pyenv/bin:$HOME/.bin:$PATH:$NPM_PACKAGES/bin:$PATH"
	export PATH="$HOME/.bin:$PATH:$NPM_PACKAGES/bin"
	export TZ="Europe/Athens"

	# Check the window size after each command to update LINES and COLUMNS if necessary
	shopt -s checkwinsize

# Alias and function definitions.
	function precmd() {
		print -Pn "\e]0;%n@%m: %~\a"
	}

	function cm() {
		mkdir -p "${1}"
		cd "${1}" || return
	}

	function encthis() {
		tar czf - "$1" | gpg -c --cipher-algo aes256 -o "$(basename $1)-$(date +%d.%m.%y).tgz.aes"
	}

	function decthis() {
		gpg -o- "$1" | tar zxvf -
	}

	# Beutiful way to show your NIC's IP/MAC address
	function netstate() {
		ifconfig | awk "/^[a-z]+[0-9]?/ || /inet/ || /ether/ { if (\$1 == \"inet\") { print \"\tIP: \" \$2 } else if (\$1 == \"inet6\") { print \"\tIPv6: \" \$2 } else if (\$1 == \"ether\") { print \"\tMAC Address: \" \$2 } else { print \"\" \$1 } }"
	}

	function bin2hex() {
		printf '0x%x\n' "$((2#${1}))"
	}

	function hex2bin() {
		echo -ne 0b
		inp=$(echo "${1}" | awk '{print toupper($0)}')
		bc <<EOF
ibase=16
obase=2
${inp}
EOF
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
		branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
		[ ! -z $branch ] && echo " $branch"
	}

	# update all git repos in current dir
	function gitup() {
		for dir in *; do
			if [ -d "$dir/.git" ]; then
				cd "$dir" || continue
				echo "$dir:"
				git pull
				cd ..
			fi
		done
	}

	# Some useful info for the prompt (background job count & task count)
	function statecnt() {
		job=$(jobs | wc -l)

		if [[ $job -ne 0 ]]; then
			echo -en "${GREEN}[${CYAN}J${job}${GREEN}]${NC}"
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

	function command_not_found_handler() {
		# Looks like a vim command
		[[ "$1" == :* ]] && {
			return $(nvr -c "${1}")
		}
		# Otherwise, replicate the default error message
		printf '(ba/z)sh: command not found: %s\n' "$1" >&2
		return 127
	}

	function tombo() {
		tomb open "${1}" -k "${1}.key" -gr "${2}"
	}

	function tombc() {
		tomb dig -s "${2}" "${1}"
		tomb forge "${1}.key" -gr "${3}"
		tomb lock "${1}" -k "${1}.key" -gr "${3}"
	}

	eval "$(dircolors -b 2>/dev/null || gdircolors -b)"

# Alias
	alias busy='my_file=$(find /usr/include -type f | sort -R | head -n 1); my_len=$(wc -l $my_file | awk "{print $1}"); let "r = $RANDOM % $my_len" 2>/dev/null; nvim +$r $my_file'
	alias docker_rm='docker rm $(docker ps --no-trunc -aqf status=exited)'
	alias docker_rmi='docker rmi $(docker images --no-trunc -qf dangling=true)'
	alias webserver='python2 -m SimpleHTTPServer'
	alias open='xdg-open'
	alias passgen='gpg --gen-random --armor 1 '

	alias diff='colordiff -ub'
	alias grep='rg'
	alias less='less -R'
	alias ll='exa -Fhalg --color=auto'
	alias ls='exa -F --color=auto'
	alias man='LC_ALL=C LANG=C man'
	# Come on mutt, we're on 2015...
	alias mutt='TERM=xterm-256color mutt'
	alias pgrep='pgrep -af'
	alias ssh='TERM=xterm-256color ssh'

	# Yey! Saved 2 keystrokes! :)
	alias 1ping='ping 1.1.1.1'
	alias cdt='cd $(mktemp -d)'
	alias d='docker'
	alias dc='docker-compose'
	alias e=${EDITOR}
	alias g='git'
	alias jc='curl -i -H "Content-Type: application/json"'
	alias ipy='ipython'
	alias l='exa --color=auto'
	alias mc='cm'
	alias n='echo -e "\a"; mpg123 -q ~/Music/notification.mp3'
	#alias mc='java -jar .minecraft/minecraft.jar'
	alias py='python'
	alias py2='python2.7'
	alias py3='python3.6'
	alias v='nvr --remote-silent'
	alias sv='sudoedit'

	# Muscle memory...
	alias :e='v'
	alias :q='exit'

# Enable completions
	if [ -f /etc/bash_completion ]; then
		. /etc/bash_completion
	fi

# Other useful definitions
	# "You are SSHing" reminder (shutdown the server maybe?)
	if [ -n "$SSH_CLIENT" ]; then
		SSH_COLOR=$RED
		SSH_INFO="@$RED$(uname -n)"

		export SSH_INFO
	else
		SSH_COLOR=$GREEN
	fi

	export PS1="${SSH_COLOR}\u${SSH_INFO} \$(statecnt && echo -n ' ')${BCYAN}\W${GREEN}\$(gitbranch)\$(gitstat)${RED}\$ ${NC}"

	# Android env vars
	export ANT_ROOT=/usr/bin/
	export ANDROID_SDK_ROOT=~/.android/sdk
	export ANDROID_HOME=~/.android/sdk
	export NDK_ROOT=~/.android/ndk

	# GoLang env vars
	export GOPATH="$HOME/go"
	export PATH="${PATH}:${GOPATH}/bin"

	# GPG-Agent SSH key
	unset SSH_AGENT_PID
	if [ "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
		export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
	fi

	if [ -f /usr/bin/virtualenvwrapper.sh ]; then
		source /usr/bin/virtualenvwrapper.sh
	elif [ -f /usr/local/bin/virtualenvwrapper.sh ]; then
		source /usr/local/bin/virtualenvwrapper.sh
	fi

	if [ -s "$HOME/.local/share/marker/marker.sh" ]; then
		export MARKER_KEY_NEXT_PLACEHOLDER="^N"
		source "$HOME/.local/share/marker/marker.sh"
	fi
