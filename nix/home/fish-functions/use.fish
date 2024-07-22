set -l packages

for arg in $argv
	if not contains -- "#" $arg
		set packages $packages "nixpkgs#$arg"
	else
		set packages $packages $arg
	end
end

echo "Entering nix shell with packages: $packages"
IN_NIX_SHELL=$argv nix shell $packages --command $SHELL
