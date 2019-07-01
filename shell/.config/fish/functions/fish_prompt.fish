function fish_prompt --description "Write out the prompt"
	set -l color_cwd
	set -l suffix

	switch "$USER"
		case root toor firefart pwn
			set color_cwd red
			set suffix '#'
		case '*'
			set color_cwd cyan
			set suffix '>'
	end

	echo -ns (set_color green) "$USER " (set_color $color_cwd) (prompt_pwd) (set_color normal) "$suffix "
end

function fish_right_prompt --description "Write out the right prompt"
	# Git Prompt
	set -l git_isdir (git rev-parse --is-inside-work-tree 2>/dev/null)

	if [ "$git_isdir" != "true" ]
		return
	end

	set -l git_state
	set -l git_ahead (git log --oneline @\{u\}.. | wc -l | tr -d ' ')
	set -l git_behind (git log --oneline ..@\{u\} | wc -l | tr -d ' ')
	# TODO: Remove (refs/heads/|tags/)
	set -l git_branch (git symbolic-ref -q HEAD || git name-rev --name-only --no-undefined --always HEAD)
	set -l git_dir (git rev-parse --git-dir)
	set -l git_untracked (git ls-files --other --exclude-standard 2> /dev/null)
	set -l git_modified (git diff --quiet)
	set -l git_staged (git diff --quiet --cached)

	echo -ns (set_color blue) "±" (set_color green) "["

	if [ $git_ahead -gt 0 ]
		set_color red
		echo -ns "A" $git_ahead
	end
	if [ $git_behind -gt 0 ]
		set_color cyan
		echo -ns "B" $git_behind
	end
	if [ -r "$git_dir/MERGE_HEAD" ]
		set_color --bold magenta
		echo -n '/!\\ '
	end
	if [ -n "$git_untracked" ]
		set_color --bold red
		echo -n '•'
	end
	if [ "$git_modified" ]
		set_color --bold yellow
		echo -n '•'
	end
	if [ "$git_staged" ]
		set_color --bold green
		echo -n '•'
	end

	echo -ns (set_color normal) "$git_branch" (set_color green) "]"

	# Job prompt
	set -l jobs (jobs | wc -l)
	if [ $jobs -gt 0 ]
		echo -ns (set_color green) "[" (set_color cyan) "J" $jobs (set_color green) "]"
	end
end
