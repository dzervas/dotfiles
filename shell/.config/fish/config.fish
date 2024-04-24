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

# Disable the greeting
set -g fish_greeting

# Configure the plugins
fzf_configure_bindings --directory=\ef --git_log=\eg --processes=\eq --variables=\ev

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
