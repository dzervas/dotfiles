{ config, pkgs, ... }:

{
	fileSystems."/" = {
		device = "root";
		fsType = "ext4";
	};
}
