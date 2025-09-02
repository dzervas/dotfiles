sudo nixos-rebuild switch --flake "$FLAKE_URL" --override-input nix-private "path:.private" $argv || return $status

set -f flake_file (echo "$FLAKE_URL" | cut -d'#' -f1 | cut -d'?' -f1)

pushd "$flake_file"
set -f nix_kernel_version (nix eval '.#nixosConfigurations.'(hostname)'.config.boot.kernelPackages.kernel.version' --raw 2>/dev/null)
set -f current_kernel_version (uname -r)
popd

if test "$nix_kernel_version" != "$current_kernel_version"
	set_color yellow
	echo "New kernel version available: $nix_kernel_version vs $current_kernel_version, please reboot"
	set_color normal
end
