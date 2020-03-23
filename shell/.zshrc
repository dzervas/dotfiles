#if [[ "$SHLVL" -eq 1 && ! -o LOGIN && -s "/etc/zprofile" ]]; then
  #source "/etc/zprofile"
#fi

# Load .bashrc
# Shopt not found workaround
alias shopt="false"
source ~/.bashrc
unalias shopt

# Modules
	autoload -U colors && colors
	autoload -U promptinit && promptinit
	autoload -U compinit && compinit
	autoload -U zmv

	zmodload zsh/zpty

# Plugins
if [ -f /usr/share/zsh/share/antigen.zsh ]; then
	source /usr/share/zsh/share/antigen.zsh
elif [ -f /usr/share/zsh-antigen/antigen.zsh ]; then
	source /usr/share/zsh-antigen/antigen.zsh
elif [ -f /usr/local/share/antigen/antigen.zsh ]; then
	source /usr/local/share/antigen/antigen.zsh
fi

antigen bundle hlissner/zsh-autopair
antigen bundle jreese/zsh-titles
antigen bundle zdharma/fast-syntax-highlighting
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle RobSis/zsh-completion-generator

antigen apply

export FZF_CTRL_T_COMMAND="fd -t f"
export FZF_CTRL_T_OPTS="--preview 'bat --paging never -p -r 0:100 {}'"
export FZF_ALT_C_COMMAND="fd -t d"
export FZF_ALT_C_OPTS="--preview 'lsd -Fal {}'"

if [ -f /usr/local/opt/fzf/shell/key-bindings.zsh ]; then
	source /usr/local/opt/fzf/shell/key-bindings.zsh
elif [ -f /usr/share/fzf/key-bindings.zsh ]; then
	source /usr/share/fzf/key-bindings.zsh
elif [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
	source /usr/share/doc/fzf/examples/key-bindings.zsh
fi

# Settings
	setopt APPEND_HISTORY
	setopt hist_ignore_all_dups	# Ignore duplicate commands from history
	setopt hist_ignore_space	# Ignore commands starting with space from history
	setopt autocd				# /etc instead of cd /etc
	setopt prompt_subst			# Update PS1 every time
	setopt transientrprompt		# Indicate insert/command mode

# Functions
	# Git prompt
	# Show Git branch/tag, or name-rev if on detached head
	parse_git_branch() {
		(git symbolic-ref -q HEAD || \
			git name-rev --name-only --no-undefined --always HEAD) 2> /dev/null
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
			echo -ne "$GIT_PROMPT_PREFIX$GIT_STATE$GIT_PROMPT_SUFFIX"
		fi
	}
 
	# If inside a Git repository, print its branch and state
	git_prompt_string() {
		local git_where="$(parse_git_branch)"
		[ -n "$git_where" ] && echo -ne "$GIT_PROMPT_SYMBOL$(parse_git_state)$GIT_PROMPT_PREFIX%{$YELLOW%}${git_where#(refs/heads/|tags/)}$GIT_PROMPT_SUFFIX$NC"
	}
	
	# Insert sudo at the beginning of the command
	insert_sudo() {
		zle beginning-of-line
		zle -U "sudo "
	}

	exec_sudo() {
		zle up-history
		zle beginning-of-line
		zle -U "sudo "
	}

	get_help() {
		cmd=${(z)BUFFER}

		if [[ $cmd = *" "* ]]; then
			cmd=${${(z)BUFFER}[1]}
			if [[ $cmd = "sudo" ]]; then
				cmd=${${(z)BUFFER}[2]}
			fi
		fi

		echo
		${cmd} --help | less
		zle reset-prompt
	}

	# Stupid ZLE hack
	goto_bg() { fg > /dev/null 2>&1 }

	# Setup:
	faraday-start() {
		tmux new -s faraday-server -d "~/.virtualenvs/faraday/bin/python ~/Tools/faraday/faraday-server.py"
		tmux new -s faraday-client -d "~/.virtualenvs/faraday/bin/python ~/Tools/faraday/faraday.py --gui no-gui"
	}

	faraday-stop() {
		tmux kill-session -t faraday-client
		tmux kill-session -t faraday-server
	}

# ZLE definitions
	zle -N exec-sudo exec_sudo
	zle -N fg goto_bg
	zle -N insert-sudo insert_sudo
	zle -N get-help get_help

# Variables
	# Colors
	NC="%{$terminfo[sgr0]%}"
	for color in BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE; do
		eval B$color='%{$fg_bold[${(L)color}]%}'
		eval $color='%{$fg[${(L)color}]%}'
	done

	# Git
	GIT_PROMPT_SYMBOL="%{$BLUE%}±"
	GIT_PROMPT_PREFIX="%{$GREEN%}["
	GIT_PROMPT_SUFFIX="%{$GREEN%}]"
	GIT_PROMPT_AHEAD="%{$RED%}ANUM"
	GIT_PROMPT_BEHIND="%{$CYAN%}BNUM"
	GIT_PROMPT_MERGING="%{$BMAGENTA%}/!\\$NC"
	GIT_PROMPT_UNTRACKED="%{$BRED%}•$NC"
	GIT_PROMPT_MODIFIED="%{$BYELLOW%}•$NC"
	GIT_PROMPT_STAGED="%{$BGREEN%}•$NC"

	HISTFILE=$HOME/.zhistory
	HISTSIZE=100000
	SAVEHIST=100000

	if [ -n "$SSH_CLIENT" ]; then
		SSH_COLOR=$RED
		export SSH_INFO="@$RED$(uname -n)$NC"
	else
		SSH_COLOR=$GREEN
	fi

	PS1='$SSH_COLOR%n${SSH_INFO} $BCYAN%c$NC%(!.#.>) '
	RPS1='$(git_prompt_string)$(statecnt)$NC'

#for f in /usr/share/*/*.zsh; do source $f; done 2>/dev/null
	hash navi && source <(navi widget zsh)

# Key bindings
	export KEYTIMEOUT=1
	bindkey -e
	bindkey "^r"		fzf-history-widget
	bindkey "^f"		fzf-file-widget
	bindkey "^g"		fzf-cd-widget
	bindkey "^h"		get-help
	bindkey "^z"		fg
	bindkey "\e\e"		insert-sudo
	bindkey "\e\`"		exec-sudo
	bindkey "\ea"		exec-sudo
	bindkey "^[[3~"		delete-char
	bindkey "\e[1~"		beginning-of-line
	bindkey "\e[4~"		end-of-line
	bindkey "\e[7~"		beginning-of-line
	bindkey "\e[8~"		end-of-line
	bindkey "\eOH"		beginning-of-line
	bindkey "\eOF"		end-of-line
	bindkey "^[[H"		beginning-of-line
	bindkey "^[[F"		end-of-line
	bindkey "^[[1;5C"	forward-word
	bindkey "^[[1;5D"	backward-word
	bindkey "^[[3;5~"	kill-word


# Style
	# Menu completion
	zstyle ':completion:*:descriptions' format '%B%d%b'
	zstyle ':completion:*' menu select
	zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
	zstyle ':completion:*' menu select=1 _complete _ignored _approximate

	# match uppercase from lowercase
	zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

	# Rebuild $PATH on each execution (may be performance intensive)
	zstyle ":completion:*:commands" rehash 1
