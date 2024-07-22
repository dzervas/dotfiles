# Argument: the command for which help is needed
set -f pager bat --color always --style plain --paging=always
set -f command $argv[1]

if test "$command" = "sudo"
	set -f command $argv[2]
end

if test -z "$command"
	echo "Usage: smart-help <command> -- $argv[2]"
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
"go:go help" \
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
if man --where $command >/dev/null 2>&1
	man $command
	return
end

# If man page fails, try --help
set -f should_exit 0
$command --help && set should_exit 1 | $pager
if $should_exit
	return
end

# Last resort: try -h
$command -h && set should_exit 1 | $pager
if $should_exit
	return
end

echo "No help found for '$command'"
return 1
