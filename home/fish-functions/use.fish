set -l packages
set -l index 1

for arg in $argv
	set index (math $index + 1)

	if test $arg = "--"
		break
	end

	if not contains -- "#" $arg
		set packages $packages "nixpkgs#$arg"
	else
		set packages $packages $arg
	end
end

echo "Entering nix shell with packages: $packages"

if test -n "$IN_NIX_SHELL"
	set -f IN_NIX_SHELL "$IN_NIX_SHELL > "
end

set -l cmd $argv[$index..-1]

if test -z "$cmd"
	set cmd $SHELL
end

NIXPKGS_ALLOW_UNFREE=1 IN_NIX_SHELL="$IN_NIX_SHELL$argv" nix shell $packages --impure --command $cmd
