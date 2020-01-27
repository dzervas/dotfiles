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
	export EDITOR="nvim"
	export HISTCONTROL="ignoredups"
	export HOSTNAME=$(hostname)
	export MANPATH="$MANPATH:$NPM_PACKAGES/share/man"
	export NPM_PACKAGES="${HOME}/.npm-packages"
	export PAGER="less"
	export LC_CTYPE=en_US.UTF-8
	export PATH="$HOME/.bin:$HOME/.local/bin:$PATH:$NPM_PACKAGES/bin:$HOME/.cargo/bin:$HOME/.STM32Cube/STM32CubeProgrammer/bin/"
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
		[ -n "$branch" ] && echo " $branch"
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

	# Change prompt of remote machine
	function ssh-fix-prompt() {
		command="mv ~/.bashrc{,.b}; sudo sed 's/^PS1=.*/PS1=\"\\\e\[${2}m\\\u\@\\\h\\\e\[0m:\\\w\\\$ \"/g' /etc/bash.bashrc > ~/.bashrc"
		if [[ ${3} == "forsure" ]]; then
			ssh -t "${1}" "$command"
		else
			echo "Usage: ${0} <ssh host> <bash color> forsure"
			echo "For colors check: http://misc.flogisoft.com/bash/tip_colors_and_formatting"
			echo "Command (did not execute):"
			echo "$command"
		fi
	}

	function nat_iface() {
		iface=$1

		if [ "$#" -lt 1 ]; then
			ip addr
			echo "Choose interface for DHCP to listen:"
			read -r iface
			echo "Choose interface to forward traffic to (can be empty):"
			read -r oface
		else
			oface=$2
		fi

		if [ -n "$oface" ]; then
			sudo iptables -t nat -A POSTROUTING -o "$oface" -j MASQUERADE
			sudo sysctl -w net.ipv4.conf.all.forwarding=1
		fi

		nmcli dev set "$iface" managed no
		sudo ip addr add 172.16.16.1/24 dev "$iface"
		sudo dnsmasq -d -i "$iface" -F 172.16.16.100,172.16.16.120
		sudo ip addr del 172.16.16.1/24 dev "$iface"
		nmcli dev set "$iface" managed yes

		if [ -n "$oface" ]; then
			sudo iptables -t nat -D POSTROUTING -o "$oface" -j MASQUERADE
			sudo sysctl -w net.ipv4.conf.all.forwarding=0
		fi
	}

	function nse_find() {
		fd "$1" /usr/share/nmap/scripts/
	}

	function openocd_find() {
		fd "$1" /usr/share/openocd/scripts/
	}

	function dump_mem() {
		grep rw-p "/proc/$1/maps" | sed -n 's/^\([0-9a-f]*\)-\([0-9a-f]*\) .*$/\1 \2/p' | while read -r start stop; do
			gdb --batch --pid "$1" -ex "dump memory $1-$start-$stop.dump 0x$start 0x$stop"
		done
	}

	eval "$(dircolors -b 2>/dev/null || gdircolors -b)"

# Alias
	alias docker_rm='docker rm $(docker ps --no-trunc -aqf status=exited)'
	alias docker_rmi='docker rmi $(docker images --no-trunc -qf dangling=true)'
	alias webserver='python3 -m http.server'
	alias open='xdg-open'
	alias passgen='gpg --armor --gen-random 2 '
	alias weather='curl wttr.in'

	alias cat='bat -p --paging=never'
	alias diff='colordiff -ub'
	alias grep='rg'
	alias less='bat -p'
	alias ll='lsd -Fal'
	alias ls='lsd -F'
	alias find='fd'
	alias man='LC_ALL=C LANG=C man'
	alias pgrep='pgrep -af'
	alias ssh='TERM=xterm-256color ssh'

	# Yey! Saved 2 keystrokes! :)
	alias 1ping='ping 1.1.1.1'
	alias cdt='cd $(mktemp -d)'
	alias d='docker'
	alias dc='docker-compose'
	alias e='$EDITOR'
	alias g='git'
	alias jc='curl -i -H "Content-Type: application/json"'
	alias ipy='ipython'
	alias l='locate -i'
	alias lp='locate -i -A "$(pwd)"'
	alias mc='cm'
	alias n='echo -e "\a"; mpg123 -q ~/Music/notification.mp3'
	#alias mc='java -jar .minecraft/minecraft.jar'
	alias py='python'
	alias py2='python2'
	alias py3='python3'
	alias v='nvim'
	alias sv='sudoedit'

	# Muscle memory...
	alias :e='v'
	alias :q='exit'

# Enable completions
	#if [ -f /etc/bash_completion ]; then
		#. /etc/bash_completion
	#fi

# Other useful definitions
	# "You are SSHing" reminder (shutdown the server maybe?)
	if [ -n "$SSH_CLIENT" ]; then
		SSH_COLOR=$RED
		SSH_INFO="@$RED$(uname -n)"

		export SSH_INFO
	else
		SSH_COLOR=$GREEN
	fi

	export PS1="${SSH_COLOR}\u${SSH_INFO}\$(statecnt && echo -n ' ')${BCYAN}\W${GREEN}\$(gitbranch)\$(gitstat)${RED}\$ ${NC}"

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
	elif [ -f /usr/share/virtualenvwrapper/virtualenvwrapper.sh ]; then
		source /usr/share/virtualenvwrapper/virtualenvwrapper.sh
	elif [ -f /usr/local/bin/virtualenvwrapper.sh ]; then
		source /usr/local/bin/virtualenvwrapper.sh
	fi

	if [ -s "$HOME/.local/share/marker/marker.sh" ]; then
		export MARKER_KEY_NEXT_PLACEHOLDER="^N"
		source "$HOME/.local/share/marker/marker.sh"
	fi