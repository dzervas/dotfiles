set -l cmd (commandline | string collect)

if test -z "$cmd"
	return
end

history delete --exact --case-sensitive -- $cmd
commandline -r ""
commandline -f repaint
