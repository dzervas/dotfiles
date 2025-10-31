#!/usr/bin/env fish

# TODO: Add completion for commit message
function __complete_smartcommit_message
	# Get the current command line buffer
	set -l token (commandline --current-token)

	# Only trigger completion if the current token starts with '#'
	if string match -q "#*" -- $token
		# Check if gh CLI is installed
		if not command -v gh >/dev/null
			return
		end

		# Fetch issues and PRs in parallel for speed
		# --json gives us structured data, --limit keeps it fast
		# We use 'begin ... end' to group the two commands into one job
		begin
			gh issue list --limit 20 --json number,title
			gh pr list --limit 20 --json number,title
		end | # Parse the JSON output and format it for fzf
		jq -r '.[] | "#\(.number): \(.title)"' |
		# Use fzf for interactive selection
		fzf --delimiter=':' --preview='gh issue view {1} || gh pr view {1}' --header="Select an issue/PR" |
		# From the selected line (e.g., "#123: Fix the bug"), extract just "#123"
		awk -F: '{print $1}'
	end
end

if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
	echo (set_color red)"Error: Not a git/jj repository."(set_color normal)
	return 1
end

set -l commit_types fix feat ci chore docs style refactor test
set -l commit_types_len (math (count $commit_types) + 3)
set -l selected_type (printf "%s\n" $commit_types | fzf --height=$commit_types_len --prompt="Commit Type: " --header="Select the type of change")

set -l git_root (git rev-parse --show-toplevel)

set -l scopes (command find $git_root -maxdepth 1 -type d -not -path '*/\.*' -printf "%f\n" | tail -n +2)
set -l scope_options None $scopes
set -l scope_options_len (math (count $scope_options) + 3)
set -l selected_scope (printf "%s\n" $scope_options | fzf --height=$scope_options_len --prompt="Scope: " --header="Select the scope of the change")

echo
read -P "Commit Message: " -l commit_message

if test -z "$commit_message"
	echo (set_color red)"Error: Commit message cannot be empty."(set_color normal)
	return 1
end

if test "$selected_scope" = "none"
	set final_message "$selected_type: $commit_message"
else
	set final_message "$selected_type($selected_scope): $commit_message"
end

echo
echo (set_color green)"--> Committing with message:"(set_color normal)
echo (set_color cyan)"    $final_message"(set_color normal)
echo

if jj --ignore-working-copy root >/dev/null 2>&1
	jj commit -m "$final_message" $argv
else
	git commit -m "$final_message" $argv
end
