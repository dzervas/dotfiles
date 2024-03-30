# If not running interactively, don't do anything
[ -z "$PS1" ] && return

bind 'set enable-bracketed-paste on'
set bell-style none

# Colors
	NC='\[\e[0m\]'       # Text Reset
	
	# Regular Colors
	export BLACK='\[\e[30m\]'        # Black
	export RED='\[\e[31m\]'          # Red
	export GREEN='\[\e[32m\]'        # Green
	export YELLOW='\[\e[33m\]'       # Yellow
	export BLUE='\[\e[34m\]'         # Blue
	export PURPLE='\[\e[35m\]'       # Purple
	export CYAN='\[\e[36m\]'         # Cyan
	export WHITE='\[\e[37m\]'        # White
	
	# Bold
	export BBLACK='\[\e[1;30m\]'       # Black
	export BRED='\[\e[1;31m\]'         # Red
	export BGREEN='\[\e[1;32m\]'       # Green
	export BYELLOW='\[\e[1;33m\]'      # Yellow
	export BBLUE='\[\e[1;34m\]'        # Blue
	export BPURPLE='\[\e[1;35m\]'      # Purple
	export BCYAN='\[\e[1;36m\]'        # Cyan
	export BWHITE='\[\e[1;37m\]'       # White

# Variable definitions
	# No duplicates in history
	export ALTERNATE_EDITOR="vim"
	export EDITOR="vim"
	export HISTCONTROL="ignoredups"
	export HOSTNAME=$(hostname)
	export PAGER="less"
	export LC_CTYPE=en_US.UTF-8
	export GOPATH="$HOME/go"
	export PATH="$HOME/.bin:$HOME/.local/bin:$PATH:$HOME/.cargo/bin:${GOPATH}/bin:$HOME/.npm-global/bin:$HOME/.krew/bin"
	export TZ="Europe/Athens"

	# Check the window size after each command to update LINES and COLUMNS if necessary
	shopt -s checkwinsize

# Helpers
	# git status for command prompt
	function gitstat() {
		if [[ $(git status 2> /dev/null | tail -n1) == \
			'no changes added to commit (use "git add" and/or "git commit -a")' ]]; then
			echo -n "!"
		elif [[ $(git status 2> /dev/null | grep ahead) != '' ]]; then
			echo -n ">>"
		fi
	}

	# git branch for command prompt
	function gitbranch() {
		branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
		[ -n "$branch" ] && echo -n " $branch"
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

	function precmd() {
		print -Pn "\e]0;%n@%m: %~\a"
	}


# Alias and function definitions.
	function mc() {
		mkdir -p "${1}"
		cd "${1}" || return
	}

	# By premek
	function mv() {
		if [ "$#" -ne 1 ] || [ ! -e "$1" ]; then
			command mv "$@"
			return
		fi

		echo -n "New filename: "
		read -ei "$1" newfilename
		command mv -v -- "$1" "$newfilename"
	}

	function kubesa() {
		if [ $# -ne 1 ]; then
			echo "Usage: $0 <service account name>"
			return
		fi

		sa_name=$1
		server=$(kubectl config view --minify --flatten -o jsonpath='{.clusters[0].cluster.server}' || return)

		if [ -z "${server}" ]; then
			echo "Could not find the server name"
			return
		fi

		name=$(kubectl get secrets -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep "^${sa_name}-token-\w+$" || return)

		if [ -z "${name}" ]; then
			echo "Could not find ServiceAccount"
			return
		fi

		ca=$(kubectl get secret/$name -o jsonpath='{.data.ca\.crt}' || return)

		if [ -z "${ca}" ]; then
			echo "Could not find CA Certificate"
			return
		fi

		token=$(kubectl get secret/$name -o jsonpath='{.data.token}' | base64 --decode || return)

		if [ -z "${token}" ]; then
			echo "Could not find Account Token"
			return
		fi

		namespace=$(kubectl get secret/$name -o jsonpath='{.data.namespace}' | base64 --decode || return)

		if [ -z "${namespace}" ]; then
			echo "Could not find Namespace"
			return
		fi

		echo "apiVersion: v1
kind: Config
clusters:
- name: default-cluster
  cluster:
    certificate-authority-data: ${ca}
    server: ${server}
contexts:
- name: default-context
  context:
    cluster: default-cluster
    namespace: ${namespace}
    user: default-user
current-context: default-context
users:
- name: default-user
  user:
    token: ${token}"
	}

	function kubeseal-env() {
		if [ "$#" -lt "1" ] || [ "$#" -gt "2" ]; then
			echo "Usage: $0 <env file> [namespace]"
			return
		fi

		env_file="$1"
		if [ ! -z "$2" ]; then
			namespace="$2"
		else
			namespace="$(kubens -c)"
		fi

		echo "Env file $env_file will be sealed for $namespace/$(kubectx -c). You sure?" >&2
		read

		kubectl create secret -n "$namespace" generic -o yaml --from-env-file "$env_file" --dry-run=client "$(basename $env_file)" | kubeseal -o yaml
	}

	function backup {
		for f in "$@"; do
			local target="$f.backup-$(date +'%Y.%m.%d-%H.%M.%S')"

			while [ -f "${target}" ]; do
				target="$f.backup-$(date +'%Y.%m.%d-%H.%M.%S')"
				sleep 1
			done

			cp -aRv "$f" "$target"
		done
	}

	eval "$(dircolors -b 2>/dev/null || gdircolors -b)"

# Alias
	# Sane defaults
	alias man='LC_ALL=C LANG=C man'
	alias pgrep='pgrep -af'
	alias ssh='TERM=xterm-256color ssh'
	alias diff='diff --color=always'
	alias now='date +"%Y.%m.%d-%H.%M.%S"'
	# By https://unix.stackexchange.com/questions/25327/watch-command-alias-expansion
	alias watch='watch -c '

	# Yey! Saved 2 keystrokes! :)
	function = { bc -l <<< "$@"; }  # '= 2+3' echoes '5'
	alias 1ping='ping 1.1.1.1'
	alias c='cargo'
	alias cdt='cd $(mktemp -d)'
	alias d='docker'
	alias dc='docker-compose'
	alias e='$EDITOR'
	alias g='git'
	alias h='helm'
	alias ipy='ipython'
	alias ipa='ip -c -br a'
	alias jc='curl -H "Content-Type: application/json"'
	alias k='kubectl'
	alias kn='kubens'
	alias kc='kubectx'
	alias l='locate -i'
	alias ll='ls -lah --color=always'
	alias lp='locate -i -A "$(pwd)"'
	alias n='echo -e "\a" && notify-send -a "Terminal" Notification!'
	alias p='podman'
	alias pc='podman-compose'
	alias py='python'
	alias py2='python2'
	alias py3='python3'
	alias v='vim'
	alias sv='sudoedit'
	alias tf='terraform'

	# Muscle memory...
	alias :e='v'
	alias :q='exit'

# Other useful definitions
	# "You are SSHing" reminder (shutdown the server maybe?)
	if [[ "$USER" == "root" ]]; then
		SSH_COLOR=$RED
		PS1_HOST="\H"
	elif [ -n "$SSH_CLIENT" ]; then
		SSH_COLOR=$BLUE
		PS1_HOST="\H"
	else
		SSH_COLOR=$GREEN
		PS1_HOST="\h"
	fi

	if [[ "$USER" != "root" ]] && [[ "$USER" != "dzervas" ]]; then
		SSH_COLOR="${SSH_COLOR}\u@"
	fi

	export PS1="${SSH_COLOR}${SSH_COLOR}${PS1_HOST} ${BCYAN}\w${BYELLOW}\$(gitbranch)${PURPLE}\$(gitstat)${NC}\$ "

	# 1password SSH agent
	unset SSH_AUTH_SOCK
	export SSH_AUTH_SOCK=~/.1password/agent.sock

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

	if [ -f /usr/share/nvm/init-nvm.sh ]; then
		source /usr/share/nvm/init-nvm.sh
	fi

	export PYENV_ROOT="$HOME/.pyenv"
	command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
	eval "$(pyenv init -)"

	# Enable completions
	if [ -f /etc/bash_completion ]; then
		source /etc/bash_completion
	fi

	if [ -f /usr/local/etc/bash_completion ]; then
		source /usr/local/etc/bash_completion
	fi

	if [ -S "$XDG_RUNTIME_DIR/podman/podman.sock" ]; then
		export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
	fi

	eval "$(register-python-argcomplete pipx)"
