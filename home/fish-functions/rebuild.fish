set -l NIXOS_LABEL
set -l git_dir (echo $FLAKE_URL | cut -d# -f1 | cut -d'?' -f1)

if test (count $argv) -gt 0
	set NIXOS_LABEL $argv[1]
	set argv $argv[2..-1]
else
	if test (git -C $git_dir status --porcelain | wc -c) -eq 0
		set NIXOS_LABEL (git -C $git_dir log -1 --pretty=%B | head -n 1)
		echo "Using last commit message: $NIXOS_LABEL"
	else
		read -l -P "Enter generation message: " msg
		set NIXOS_LABEL $msg
	end
end

if test -z $NIXOS_LABEL
	echo "No message provided, will auto-generate"
end

sudo nixos-rebuild switch --flake $FLAKE_URL $argv
