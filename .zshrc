######################################################################
#           jdong's zshrc file v0.2.1 , based on:
#		      mako's zshrc file, v0.1
#
# 
######################################################################

# Load .bashrc
# Shopt not found workaround
alias shopt="false"
source ~/.bashrc
unalias shopt

# Settings
	setopt APPEND_HISTORY
	setopt CORRECT			# command CORRECTION
	setopt hist_ignore_all_dups	# Ignore duplicate commands from history
	setopt hist_ignore_space	# Ignore commands starting with space from history
	setopt autocd			# /etc instead of cd /etc
	setopt prompt_subst		# Update PS1 every time
	setopt transientrprompt		# Indicate insert/command mode

# Modules
	autoload -U colors && colors
	autoload -U promptinit && promptinit

# Functions
	# Git prompt
	# Show Git branch/tag, or name-rev if on detached head
	parse_git_branch() {
		(git symbolic-ref -q HEAD || git name-rev --name-only --no-undefined --always HEAD) 2> /dev/null
	}

	# Show different symbols as appropriate for various Git repository states
	parse_git_state() {
		# Compose this value via multiple conditional appends.
		local GIT_STATE=""
		local NUM_AHEAD="$(git log --oneline @{u}.. 2> /dev/null | wc -l | tr -d ' ')"
		local NUM_BEHIND="$(git log --oneline ..@{u} 2> /dev/null | wc -l | tr -d ' ')"
		local GIT_DIR="$(git rev-parse --git-dir 2> /dev/null)"
		if [ "$NUM_AHEAD" -gt 0 ]; then
			GIT_STATE=$GIT_STATE${GIT_PROMPT_AHEAD//NUM/$NUM_AHEAD}
		fi
		if [ "$NUM_BEHIND" -gt 0 ]; then
			GIT_STATE=$GIT_STATE${GIT_PROMPT_BEHIND//NUM/$NUM_BEHIND}
		fi
		if [ -n $GIT_DIR ] && test -r $GIT_DIR/MERGE_HEAD; then
			GIT_STATE=$GIT_STATE$GIT_PROMPT_MERGING
		fi
		if [[ -n $(git ls-files --other --exclude-standard 2> /dev/null) ]]; then
			GIT_STATE=$GIT_STATE$GIT_PROMPT_UNTRACKED
		fi
		if ! git diff --quiet 2> /dev/null; then
			GIT_STATE=$GIT_STATE$GIT_PROMPT_MODIFIED
		fi
		if ! git diff --cached --quiet 2> /dev/null; then
			GIT_STATE=$GIT_STATE$GIT_PROMPT_STAGED
		fi
		if [[ -n $GIT_STATE ]]; then
			echo "$GIT_PROMPT_PREFIX$GIT_STATE$GIT_PROMPT_SUFFIX"
		fi
	}
 
	# If inside a Git repository, print its branch and state
	git_prompt_string() {
		local git_where="$(parse_git_branch)"
		[ -n "$git_where" ] && echo "$GIT_PROMPT_SYMBOL$(parse_git_state)$GIT_PROMPT_PREFIX%{$fg[yellow]%}${git_where#(refs/heads/|tags/)}$GIT_PROMPT_SUFFIX"
	}
	
	# Insert sudo at the beginning of the command
	insert_sudo () {
		zle beginning-of-line
		zle -U "sudo "
#		zle end-of-line
	}

	fake-accept-line() {
		if [[ -n "$BUFFER" ]]; then
			print -S "$BUFFER"
		fi
		return 0
	}

	down-or-fake-accept-line() {
		if (( HISTNO == HISTCMD )) && [[ "$RBUFFER" != *$'\n'* ]]; then
			zle fake-accept-line
		fi
		zle .down-line-or-history "$@"
	}

# ZLE definitions
	zle -N insert-sudo insert_sudo
	zle -N fake-accept-line
	zle -N down-line-or-history down-or-fake-accept-line

# Variables
	export EDITOR="vim"
	# Colors
	for color in BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE; do
		eval B$color='%{$terminfo[bold]$fg[${(L)color}]%}'
		eval $color='%{$fg[${(L)color}]%}'
	done
	NC="%{$terminfo[sgr0]%}"

	# Git
	GIT_PROMPT_SYMBOL="%{$fg[blue]%}±"
	GIT_PROMPT_PREFIX="%{$fg[green]%}[%{$reset_color%}"
	GIT_PROMPT_SUFFIX="%{$fg[green]%}]%{$reset_color%}"
	GIT_PROMPT_AHEAD="%{$fg[red]%}ANUM%{$reset_color%}"
	GIT_PROMPT_BEHIND="%{$fg[cyan]%}BNUM%{$reset_color%}"
	GIT_PROMPT_MERGING="%{$fg_bold[magenta]%}/!\\%{$reset_color%}"
	GIT_PROMPT_UNTRACKED="%{$fg_bold[red]%}•%{$reset_color%}"
	GIT_PROMPT_MODIFIED="%{$fg_bold[yellow]%}•%{$reset_color%}"
	GIT_PROMPT_STAGED="%{$fg_bold[green]%}•%{$reset_color%}"

	TZ="Europe/Athens"
	HISTFILE=$HOME/.zhistory
	HISTSIZE=1000
	SAVEHIST=1000
	HOSTNAME="`hostname`"
	PAGER='less'
	if [ -n "$SSH_CLIENT" ]; then
		SSH_COLOR=$RED
		export SSH_INFO="@$RED$(uname -n)$NC"
	else
		SSH_COLOR=$GREEN
	fi
	PS1="$SSH_COLOR%n $BCYAN%c$NC%(!.#.>) "
	RPS1='${SSH_INFO}$(git_prompt_string)'

# Aliases
	# Called with "cclin <ip>:<port>"
	alias cclin='openssl s_client -quiet -connect '
	# Called with "cserv <port>"
	# Needs .cserv.pem generated with:
	# openssl req -x509 -nodes -days 365 -newkey rsa:8192 -keyout ~/.cserv.pem -out ~/.cserv.pem
	alias cserv='openssl s_server -quiet -cert ~/.cserv.pem -accept '
	alias fuck='sudo $(fc -l -n -1)'
	alias ls='ls --color=auto '
	alias ll='ls -al --color=auto'
	alias man='LC_ALL=C LANG=C man'


# Key bindings
#	bindkey -v		# VI key bindings
	bindkey "^r"		history-incremental-search-backward
	bindkey "^y"		insert-sudo
	bindkey "^[[3~"		delete-char
	bindkey "\e[1~"		beginning-of-line
	bindkey "\e[4~"		end-of-line
	bindkey "\e[7~"		beginning-of-line
	bindkey "\e[8~"		end-of-line
	bindkey "\eOH"		beginning-of-line
	bindkey "\eOF"		end-of-line
	bindkey "^[[H"		beginning-of-line
	bindkey "^[[F"		end-of-line

# Style
	# Menu completion
	zstyle ':completion:*:descriptions' format '%B%d%b'
	zstyle ':completion:*' menu select
	zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
	zstyle ':completion:*' menu select=1 _complete _ignored _approximate

	# match uppercase from lowercase
	zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
	
	autoload -U compinit && compinit
