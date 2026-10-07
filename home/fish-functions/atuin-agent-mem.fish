set -l root $PWD
set -l in_repo
while test "$root" != /
	if test -e "$root/.git"; or test -e "$root/.jj"
		set in_repo 1
		break
	end
	set root (dirname $root)
end
# Same fallback as the memory tool: nothing above here is a repository, so the directory names it.
test -z "$in_repo"; and set root $PWD

set -l slug
set -l remote (git -C "$root" remote get-url origin 2>/dev/null)
if test -n "$remote"
	set slug (string replace -r '^(?:git@|ssh://|https?://|file://)?[^/:]+[/:](.+?)(?:\.git)?$' '$1' -- $remote)
else
	set slug (basename $root)
	echo "pi/$slug - named from the directory name, no git remote, so not stable across machines"
end

for namespace in pi/global "pi/$slug"
	echo "$namespace"
	set -l values
	for key in (atuin-agent kv list -n $namespace)
		set -l value (atuin-agent kv get -n $namespace $key)
		test -n "$value"; and set values $values $value
	end
	if test -z "$values"
		echo "(no notes)"
	else
		string join \n $values | sort
	end
	echo
end
