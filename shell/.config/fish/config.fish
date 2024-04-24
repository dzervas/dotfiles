if not status is-interactive
    exit
end

function smart-help
    # Argument: the command for which help is needed
    set -f pager bat --color always --style plain --paging=always
    set -f argv (string trim $argv)
    set -f command (echo $argv | cut -d ' ' -f 1)

    if test "$command" = "sudo"
        set -f command (echo $argv | cut -d ' ' -f 2)
    end

    if test -z "$command"
        echo "Usage: smart-help <command>a -- $(echo $argv | cut -d ' ' -f 2)"
        return
    end

    # Fish has just functions, not aliases and we need to resolve them to check
    # for man pages
    if test (type -t $command) = "function"
        # If a function "wraps" a command (fish's way of carrying-over completion), it will be executed instead of the command
        if set -l wrapped (functions $command | head -n 2 | tail -n 1 | command grep -oP '(?<=--wraps=)\w+')
            set -f command $wrapped
        # If a function has the same name with a command, it will be executed instead of the command
        else if set -l same_exec (type -a $command | tail -n 1 | command grep "$command is ")
            set -f command (echo $same_exec | cut -d ' ' -f 3)
        end
    end

    # Define overrides (map of commands to alternative help commands)
    # Example: set overrides['git'] 'git help -a'
    set -f overrides \
        "git:git help -a" \
        "npm:npm help 5"

    # Check for overrides and execute if present
    for override in $overrides
        set -l key (echo $override | cut -d ':' -f 1)
        set -l value (echo $override | cut -d ':' -f 2-)

        if test "$key" = "$command"
            eval $value | $pager
            return
        end
    end

    # Try to open the man page
    if man $command >/dev/null 2>&1
        man $command
        return
    end

    # If man page fails, try --help
    if $command --help >/dev/null 2>&1
        $command --help | $pager
        return
    end

    # Last resort: try -h
    if $command -h >/dev/null 2>&1
        $command -h | $pager
    else
        echo "No help found for '$command'"
    end
end

function backup
	for file in $argv
		set -l target "$file.backup-$(date +'%Y.%m.%d-%H.%M.%S')"

		while test -f "$target"
			set -l target "$file.backup-$(date +'%Y.%m.%d-%H.%M.%S')"
			sleep 1
		end

		cp -aRv "$file" "$target"
	end
end

function kubeseal-env
	if test (count $argv) -lt 1 -o (count $argv) -gt 2 -o "$argv[1]" = "-h" -o "$argv[1]" = "--help"
		echo "Usage: kubeseal-env <env file> [namespace]"
		return 1
	end

	set -f env_file $argv[1]
	set -f namespace $argv[2]

	if test -z $argv[2]
		set -f namespace (kubens -c)
	end

	echo "Env file $env_file will be sealed for $namespace/$(kubectx -c). You sure?" >&2
	read

	kubectl create secret -n "$namespace" generic -o yaml --from-env-file "$env_file" --dry-run=client (basename $env_file) | kubeseal -o yaml
end

# Disable the greeting
set -g fish_greeting

# Configure the plugins
fzf_configure_bindings --directory=\ef --git_log=\eg --processes=\eq --variables=\ev
direnv hook fish | source

# Configure shell stuff
set -x SSH_AUTH_SOCK ~/.1password/agent.sock
if test -S $XDG_RUNTIME_DIR/podman/podman.sock
	set -x DOCKER_HOST unix://$XDG_RUNTIME_DIR/podman/podman.sock
	set -x KIND_EXPERIMENTAL_PROVIDER podman
end

# Key bindings
bind \e\e "fish_commandline_prepend sudo"
bind \e\` "smart-help (commandline -p)"

# Fix some aliases
source ~/.bash_aliases
function man --wraps=man
    LC_ALL=C LANG=C command man $argv
end

function pgrep --wraps=pgrep
    command pgrep -af $argv
end

function ssh --wraps=ssh
    TERM=xterm-256color command ssh $argv
end

function diff --wraps=diff
    command diff --color=always $argv
end

function watch --wraps=watch
    command watch -c $argv
end
