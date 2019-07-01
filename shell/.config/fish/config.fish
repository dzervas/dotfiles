function prepend_sudo --description "Prepend sudo to the current line"
	#set -l cursor_old (commandline -C)

	commandline -C 0
	commandline -i "sudo "
	#commandline -C $cursor_old
end

function prepend_sudo_previous --description "Get previous command and prepend sudo to it"
	commandline -r "sudo $history[1]"
end

function get_help --description "Get help for the current command"
	commandline | read -la cmdline
	set -l cmd $cmdline[1]

	if [ $cmd == "sudo" ]
		$cmd = $cmdline[2]
	end

	$cmd --help | less -R
	commandline -f repaint
end

bind \ch  "get_help"
bind \e\e "prepend_sudo"
bind \ea  "prepend_sudo_previous"
