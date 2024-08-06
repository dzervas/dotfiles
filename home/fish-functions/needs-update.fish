set -f flake_dir (echo $FLAKE_URL | cut -d'?' -f 1 | cut -d'#' -f 1)
set -f flake_lock "$flake_dir/flake.lock"

set -f current_sha (jq -r '.nodes.nixpkgs.locked.rev' $flake_lock)
set -f owner (jq -r '.nodes.nixpkgs.locked.owner' $flake_lock)
set -f repo (jq -r '.nodes.nixpkgs.locked.repo' $flake_lock)
set -f branch (jq -r '.nodes.nixpkgs.original.ref' $flake_lock)

function curl-gh
	curl -s -H "Accept: application/vnd.github+json" "https://api.github.com/repos/$owner/$repo/$argv"
end

set -f current_commit_date (curl-gh "commits/$current_sha" | jq -r '.commit.committer.date')
set -f commits (curl-gh "commits?sha=$branch&since=$current_commit_date" | jq -r '. | length')

if test $commits -gt 1
	echo "Needs update"
	return 1
else
	echo "Up to date"
	return 0
end
