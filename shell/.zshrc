# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
(( ${+commands[direnv]} )) && emulate zsh -c "$(direnv export zsh)"

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

(( ${+commands[direnv]} )) && emulate zsh -c "$(direnv hook zsh)"

# Load .bashrc
# Shopt not found workaround
alias bind="false"
alias shopt="false"

autoload -U promptinit && promptinit
autoload -U bashcompinit && bashcompinit
autoload -U compinit && compinit

source ~/.bashrc

unalias shopt
unalias bind
bindkey -e

export GPG_TTY=$TTY

# Modules
autoload -U colors && colors
autoload -U zmv

zmodload zsh/zpty

# Plugins
if [ -f ~/.antigen.zsh ]; then
	source ~/.antigen.zsh
elif [ -f /usr/share/zsh/share/antigen.zsh ]; then
	source /usr/share/zsh/share/antigen.zsh
elif [ -f /usr/share/zsh-antigen/antigen.zsh ]; then
	source /usr/share/zsh-antigen/antigen.zsh
elif [ -f /usr/local/share/antigen/antigen.zsh ]; then
	source /usr/local/share/antigen/antigen.zsh
fi

antigen theme romkatv/powerlevel10k

antigen bundle hlissner/zsh-autopair
antigen bundle jreese/zsh-titles
antigen bundle zdharma-continuum/fast-syntax-highlighting
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle dzervas/fzf-command-bookmarks

antigen apply

command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

# FZF configuration
if [ -f /usr/local/opt/fzf/shell/key-bindings.zsh ]; then
	source /usr/local/opt/fzf/shell/key-bindings.zsh
elif [ -f /usr/share/fzf/key-bindings.zsh ]; then
	source /usr/share/fzf/key-bindings.zsh
elif [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
	source /usr/share/doc/fzf/examples/key-bindings.zsh
fi

export FZF_CTRL_T_COMMAND="fd -t f"
export FZF_CTRL_T_OPTS="--preview 'bat -p -f --paging never -r 0:20 {}'"
export FZF_ALT_C_COMMAND="fd -t d"
export FZF_ALT_C_OPTS="--preview 'lsd --color always -Fal {}'"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"

# ZSH Settings
setopt append_history
setopt bang_hist
setopt hist_expire_dups_first
setopt hist_ignore_all_dups	# Ignore duplicate commands from history
setopt hist_ignore_space	# Ignore commands starting with space from history
setopt hist_reduce_blanks
setopt hist_save_no_dups
setopt hist_verify
setopt share_history

# Internal Functions
	# Advanced mv by a comment to premek by cameronsstone
	function mv() {
		if [ "$#" -ne 1 ] || [ ! -e "$1" ]; then
			command mv "$@"
			return
		fi

		echo -n "New filename: "
		newfilename="$1"
		vared newfilename
		command mv -v -- "$1" "$newfilename"
	}

	# Insert sudo at the beginning of the command
	function insert_sudo() {
		zle beginning-of-line
		zle -U "sudo "
	}

	function exec_sudo() {
		zle up-history
		zle beginning-of-line
		zle -U "sudo "
	}

	function get_help() {
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
	function goto_bg() { fg > /dev/null 2>&1 }

# Direct functions
	# Adafruit NRF52 flashing helper
	function adafruit-nrfutil-hex() {
		port=${1}
		file=${2}

		if [ "$#" -ne 2 ]; then
			echo "Usage: $0 <port> <hex_file>"
			return 1
		fi

		if [ "$(file "${file}" | cut -d' ' -f 2)" = "ELF" ]; then
			echo "[+] Converting ELF file to hex"
			objcopy -O ihex "${file}" "${file}.hex"
			file="${file}.hex"
		fi

		echo "[+] Generating package"
		adafruit-nrfutil dfu genpkg --dev-type 0x0052 --application "${file}" "${file}.zip"
		echo "[+] Flashing package over UART"
		adafruit-nrfutil --verbose dfu serial --package "${file}.zip" --port "${port}" --baudrate 115200 --singlebank --touch 1200
	}

	function dump-mem() {
		grep rw-p "/proc/$1/maps" | sed -n 's/^\([0-9a-f]*\)-\([0-9a-f]*\) .*$/\1 \2/p' | while read -r start stop; do
			gdb --batch --pid "$1" -ex "dump memory $1-$start-$stop.dump 0x$start 0x$stop"
		done
	}

	function nse-find() {
		fd "$1" /usr/share/nmap/scripts/
	}

	function openocd-find() {
		fd "$1" /usr/share/openocd/scripts/
	}

	function sshmux() {
		ssh -t $@ "tmux attach || tmux new"
	}

	function ssh-copy-bashrc() {
		cat ~/.bashrc | ssh $@ "cat > ~/.bashrc"
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

	HISTFILE=$HOME/.zhistory
	HISTSIZE=100000
	SAVEHIST=100000

	EDITOR="nvim"

	if [ -n "$SSH_CLIENT" ]; then
		SSH_COLOR=$RED
		export SSH_INFO="@$RED$(uname -n)$NC"
	else
		SSH_COLOR=$GREEN
	fi

#for f in /usr/share/*/*.zsh; do source $f; done 2>/dev/null

# Key bindings
	export KEYTIMEOUT=1
	bindkey "^r"		fzf-history-widget
	bindkey "^f"		fzf-file-widget
	bindkey "^g"		fzf-cd-widget
	bindkey "^z"		fg
	bindkey "^I"		expand-or-complete-prefix
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
	# Custom mv
	compdef mv=ls
	# Menu completion
	zstyle ':completion:*:descriptions' format '%B%d%b'
	zstyle ':completion:*' menu select
	zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
	zstyle ':completion:*' menu select=1 _complete _ignored _approximate

	# match uppercase from lowercase
	zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
