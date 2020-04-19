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

# Helpers
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

	if [ -n "$SSH_CLIENT" ]; then
		function hash() {
			hash $@ 2>/dev/null
		}
	fi

	function precmd() {
		print -Pn "\e]0;%n@%m: %~\a"
	}

	# Some useful info for the prompt (background job count & task count)
	function statecnt() {
		job=$(jobs | wc -l)

		if [[ $job -ne 0 ]]; then
			echo -en "${GREEN}[${CYAN}J${job}${GREEN}]${NC}"
		fi
	}


# Alias and function definitions.
	function dump_mem() {
		grep rw-p "/proc/$1/maps" | sed -n 's/^\([0-9a-f]*\)-\([0-9a-f]*\) .*$/\1 \2/p' | while read -r start stop; do
			gdb --batch --pid "$1" -ex "dump memory $1-$start-$stop.dump 0x$start 0x$stop"
		done
	}

	function mc() {
		mkdir -p "${1}"
		cd "${1}" || return
	}

	function nse_find() {
		fd "$1" /usr/share/nmap/scripts/
	}

	function openocd_find() {
		fd "$1" /usr/share/openocd/scripts/
	}

	# Change prompt of remote machine
	function ssh-copy-bashrc() {
		cat ~/.bashrc | ssh $@ "cat > ~/.bashrc"
	}

	function sshmux() {
		ssh -t $@ "tmux attach || tmux new"
	}

	eval "$(dircolors -b 2>/dev/null || gdircolors -b)"

# Alias
	# Bookmarks
	alias docker_rm='docker rm $(docker ps --no-trunc -aqf status=exited)'
	alias docker_rmi='docker rmi $(docker images --no-trunc -qf dangling=true)'
	alias webserver='python3 -m http.server'
	hash xdg-open 2>/dev/null && alias open='xdg-open'
	alias passgen='gpg --armor --gen-random 2 '
	alias weather='curl wttr.in'

	# Sane defaults
	alias man='LC_ALL=C LANG=C man'
	alias pgrep='pgrep -af'
	alias ssh='TERM=xterm-256color ssh'

	# Hipster tools
	hash bat && alias cat='bat -p --paging=never'
	hash colordiff && alias diff='colordiff -ub'
	hash rg && alias grep='rg'
	hash bat && alias less='bat -p'
	hash lsd && alias ll='lsd -Fal'
	hash lsd && alias ls='lsd -F'
	hash fd && alias find='fd'

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
	alias n='echo -e "\a"; mpg123 -q ~/Music/notification.mp3'
	alias py='python'
	alias py2='python2'
	alias py3='python3'
	alias v='nvim'
	alias sv='sudoedit'
	alias tf='terraform'

	# Muscle memory...
	alias :e='v'
	alias :q='exit'

# Other useful definitions
	# "You are SSHing" reminder (shutdown the server maybe?)
	if [ -n "$SSH_CLIENT" ]; then
		if [ "$USER" == "root" ]; then
			SSH_COLOR=$RED
		else
			SSH_COLOR=$BLUE
		fi
	else
		SSH_COLOR=$GREEN
	fi

	export PS1="${SSH_COLOR}\u@${SSH_COLOR}$(uname -n)\$(statecnt && echo -n ' ')${BCYAN}\W${GREEN}\$(gitbranch)\$(gitstat)${NC}\$ "

	# GoLang env vars
	export GOPATH="$HOME/go"
	export PATH="${PATH}:${GOPATH}/bin"

	# GPG-Agent SSH key
	unset SSH_AGENT_PID
	if [ "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
		export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
	fi

	# I love how virtualenv has crawled itself to every possible path
	if [ -f /usr/bin/virtualenvwrapper.sh ]; then
		source /usr/bin/virtualenvwrapper.sh
	elif [ -f /usr/share/virtualenvwrapper/virtualenvwrapper.sh ]; then
		source /usr/share/virtualenvwrapper/virtualenvwrapper.sh
	elif [ -f /usr/local/bin/virtualenvwrapper.sh ]; then
		source /usr/local/bin/virtualenvwrapper.sh
	elif [ -f /usr/local/bin/pyenv-sh-virtualenvwrapper ]; then
		source /usr/local/bin/pyenv-sh-virtualenvwrapper
	fi

	if which pyenv-virtualenv-init > /dev/null; then
		eval "$(pyenv virtualenv-init -)"
	fi

	# Enable completions
	#if [ -f /etc/bash_completion ]; then
		#. /etc/bash_completion
	#fi

	if [ -f /usr/local/etc/bash_completion ]; then
		source /usr/local/etc/bash_completion
	fi

	#hash navi && source <(navi widget bash)
