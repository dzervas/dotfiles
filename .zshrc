######################################################################
#           jdong's zshrc file v0.2.1 , based on:
#		      mako's zshrc file, v0.1
#
# 
######################################################################

# Settings
	# setopt NOHUP
	# setopt NOTIFY
	# setopt NO_FLOW_CONTROL
#	setopt INC_APPEND_HISTORY SHARE_HISTORY
	setopt APPEND_HISTORY
	# setopt AUTO_LIST		# these two should be turned off
	# setopt AUTO_REMOVE_SLASH
	# setopt AUTO_RESUME		# tries to resume command of same name
#	unsetopt BG_NICE		# do NOT nice bg commands
	setopt CORRECT			# command CORRECTION
#	setopt EXTENDED_HISTORY		# puts timestamps in the history
	# setopt HASH_CMDS		# turns on hashing
#	setopt MENUCOMPLETE
#	setopt ALL_EXPORT
#	setopt   notify globdots correct pushdtohome cdablevars autolist
#	setopt   correctall autocd recexact longlistjobs
#	setopt   autoresume histignoredups pushdsilent 
#	setopt   autopushd pushdminus extendedglob rcquotes mailwarning
#	unsetopt bgnice autoparamslash
	setopt hist_ignore_all_dups	# Ignore duplicate commands from history
	setopt hist_ignore_space	# Ignore commands starting with space from history
	setopt autocd			# /etc instead of cd /etc
	setopt prompt_subst		# Update PS1 every time
	setopt transientrprompt		# Indicate insert/command mode

# Modules
#	zmodload -a zsh/stat stat
#	zmodload -a zsh/zpty zpty
#	zmodload -a zsh/zprof zprof
#	zmodload -ap zsh/mapfile mapfile
#	autoload colors zsh/terminfo
	autoload -U colors && colors
#	autoload -U compinit && compinit
	autoload -U promptinit && promptinit

# Functions
	# Show Git branch/tag, or name-rev if on detached head
#	function parse_git_branch() {
#		(git symbolic-ref -q HEAD || git name-rev --name-only --no-undefined --always HEAD) 2> /dev/null
#	}

	function current_branch() {
		ref=$(git symbolic-ref HEAD 2> /dev/null) || \
		ref=$(git rev-parse --short HEAD 2> /dev/null) || return
		return ${ref#refs/heads/}
	}

	function current_repository() {
		ref=$(git symbolic-ref HEAD 2> /dev/null) || \
		ref=$(git rev-parse --short HEAD 2> /dev/null) || return
		return $(git remote -v | cut -d':' -f 2)
	}


	# Show different symbols as appropriate for various Git repository states
	parse_git_state() {

		# Compose this value via multiple conditional appends.
		local GIT_STATE=""

		local NUM_AHEAD="$(git log --oneline @{u}.. 2> /dev/null | wc -l | tr -d ' ')"
		if [ "$NUM_AHEAD" -gt 0 ]; then
			GIT_STATE=$GIT_STATE${GIT_PROMPT_AHEAD//NUM/$NUM_AHEAD}
		fi

		local NUM_BEHIND="$(git log --oneline ..@{u} 2> /dev/null | wc -l | tr -d ' ')"
		if [ "$NUM_BEHIND" -gt 0 ]; then
			GIT_STATE=$GIT_STATE${GIT_PROMPT_BEHIND//NUM/$NUM_BEHIND}
		fi

		local GIT_DIR="$(git rev-parse --git-dir 2> /dev/null)"
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
		zle end-of-line
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
	# Colors
	for color in BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE; do
		eval B$color='%{$terminfo[bold]$fg[${(L)color}]%}'
		eval $color='%{$fg[${(L)color}]%}'
	done
	NC="%{$terminfo[sgr0]%}"

	# Git
	GIT_PROMPT_SYMBOL="$fg[blue]±"
	GIT_PROMPT_PREFIX="$fg[green][$reset_color"
	GIT_PROMPT_SUFFIX="$fg[green]]$reset_color"
	GIT_PROMPT_AHEAD="$fg[red]ANUM$reset_color"
	GIT_PROMPT_BEHIND="$fg[cyan]BNUM$reset_color"
	GIT_PROMPT_MERGING="$fg_bold[magenta]⚡︎$reset_color"
	GIT_PROMPT_UNTRACKED="$fg_bold[red]●$reset_color"
	GIT_PROMPT_MODIFIED="$fg_bold[yellow]●$reset_color"
	GIT_PROMPT_STAGED="$fg_bold[green]●$reset_color"


	TZ="Europe/Athens"
	HISTFILE=$HOME/.zhistory
	HISTSIZE=1000
	SAVEHIST=1000
	HOSTNAME="`hostname`"
	PAGER='less'
	EDITOR='vim'
	PS1="$BBLUE%n $RED%c$NC%(!.#.$) "
	RPS1="$(git_prompt_string)"
#	RPS1="$PR_LIGHT_YELLOW(%D{%m-%d %H:%M})$PR_NO_COLOR"
	#LANGUAGE=

#	LC_ALL='en_US.UTF-8'
#	LANG='en_US.UTF-8'
#	LC_CTYPE=C

#	MUTT_EDITOR=vim
	# if [ $SSH_TTY ]; then
		# MUTT_EDITOR=vim
	# else
		# MUTT_EDITOR=emacsclient.emacs-snapshot
	# fi

#	unsetopt ALL_EXPORT

# Aliases
	alias man='LC_ALL=C LANG=C man'
	alias ll='ls -al'
	alias ls='ls --color=auto '


## Key bindings
	bindkey -v		# VI key bindings
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
#	bindkey '^[[5~' up-line-or-history
#	bindkey '^[[6~' down-line-or-history
#	bindkey ' ' magic-space    # also do history expansion on space
#	bindkey '^I' complete-word # complete on tab, leave expansion to _expand
#
# Style
	zstyle ':completion:*:descriptions' format '%B%d%b'
	zstyle ':completion:*' menu select
	zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
#	zstyle ':completion:*' list-prompt '%SAt %p: Hit TAB for more, or the character to insert%s'
	zstyle ':completion:*' menu select=1 _complete _ignored _approximate
#	zstyle -e ':completion:*:approximate:*' max-errors 'reply=( $(( ($#PREFIX+$#SUFFIX)/2 )) numeric )'
#	zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'
#	zstyle ':completion:*::::' completer _expand _complete _ignored _approximate
#
#	# allow one error for every three characters typed in approximate completer
#	zstyle -e ':completion:*:approximate:*' max-errors 'reply=( $(( ($#PREFIX+$#SUFFIX)/2 )) numeric )'
#
#	# insert all expansions for expand completer
#	zstyle ':completion:*:expand:*' tag-order all-expansions
#	# formatting and messages
#	zstyle ':completion:*' verbose yes
#	zstyle ':completion:*:messages' format '%d'
#	zstyle ':completion:*:warnings' format 'No matches for: %d'
#	zstyle ':completion:*:corrections' format '%B%d (errors: %e)%b'
#	zstyle ':completion:*' group-name ''
#
#	# match uppercase from lowercase
	zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
#
#	# offer indexes before parameters in subscripts
#	zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters
#
#	# command for process lists, the local web server details and host completion
#	# on processes completion complete all user processes
#	# zstyle ':completion:*:processes' command 'ps -au$USER'
#
#	## add colors to processes for kill completion
#	zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
#
#	#zstyle ':completion:*:processes' command 'ps ax -o pid,s,nice,stime,args | sed "/ps/d"'
#	zstyle ':completion:*:*:kill:*:processes' command 'ps --forest -A -o pid,user,cmd'
#	zstyle ':completion:*:processes-names' command 'ps axho command' 
#	#zstyle ':completion:*:urls' local 'www' '/var/www/htdocs' 'public_html'
#	#
#	#NEW completion:
#	# 1. All /etc/hosts hostnames are in autocomplete
#	# 2. If you have a comment in /etc/hosts like #%foobar.domain,
#	#    then foobar.domain will show up in autocomplete!
#	zstyle ':completion:*' hosts $(awk '/^[^#]/ {print $2 $3" "$4" "$5}' /etc/hosts | grep -v ip6- && grep "^#%" /etc/hosts | awk -F% '{print $2}') 
#	# Filename suffixes to ignore during completion (except after rm command)
#	zstyle ':completion:*:*:(^rm):*:*files' ignored-patterns '*?.o' '*?.c~' \
#	    '*?.old' '*?.pro'
#	# the same for old style completion
#	#fignore=(.o .c~ .old .pro)
#	
#	# ignore completion functions (until the _ignored completer)
#	zstyle ':completion:*:functions' ignored-patterns '_*'
#	zstyle ':completion:*:*:*:users' ignored-patterns adm apache bin daemon games gdm halt ident junkbust lp mail mailnull named news nfsnobody nobody nscd ntp operator pcap postgres radvd \
#	rpc rpcuser rpm shutdown squid sshd sync uucp vcsa xfs avahi-autoipd avahi backup messagebus beagleindex debian-tor dhcp dnsmasq fetchmail firebird gnats haldaemon hplip irc klog list man cupsys postfix\
#	proxy syslog www-data mldonkey sys snort
#	# SSH Completion
#	zstyle ':completion:*:scp:*' tag-order files users 'hosts:-host hosts:-domain:domain hosts:-ipaddr"IP\ Address *'
#	zstyle ':completion:*:scp:*' group-order files all-files users hosts-domain hosts-host hosts-ipaddr
#	zstyle ':completion:*:ssh:*' tag-order users 'hosts:-host hosts:-domain:domain hosts:-ipaddr"IP\ Address *'
#	zstyle ':completion:*:ssh:*' group-order hosts-domain hosts-host users hosts-ipaddr
#	zstyle '*' single-ignored show
#	
autoload -U compinit && compinit
