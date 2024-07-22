set -f git_dir (echo "$FLAKE_URL" | cut -d# -f1 | cut -d'?' -f1)
set -f fish_trace 1

sudo nixos-rebuild switch --flake "$FLAKE_URL" $argv || return 1
set -fe fish_trace

if test (git -C "$git_dir" status --porcelain | wc -c) -eq 0
	return 0
end

read -fP "Commit & push changes? [Y/n] " commit

# If it's not empty and not "Y" or "y"
if test "$commit" != "Y"; and test "$commit" != "y"; and test -n "$commit"
	return 0
end

read -fP "Commit message ('u' auto-generates an update message): " commit_msg
if test -z "$commit_msg"
	echo "No commit message provided, exiting"
	return 0
end

if test "$commit_msg" = "u"; or test "$commit_msg" = "U"
	set -f commit_msg "Update $(date)"
end

git -C $git_dir add -A
git -C $git_dir commit -m "$commit_msg"
git -C $git_dir push
