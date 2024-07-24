set -l packages

for arg in $argv
	if not contains -- "#" $arg
		set packages $packages "nixpkgs#$arg"
	else
		set packages $packages $arg
	end
end

echo "Entering nix shell with packages: $packages"
NIXPKGS_ALLOW_UNFREE=1 IN_NIX_SHELL=$argv nix shell $packages --impure --command $SHELL
