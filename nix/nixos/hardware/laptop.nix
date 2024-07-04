{ config, pkgs, ... }:

{
	powerManagement.enable = true;

	boot = {
		loader = {
			systemd-boot.enable = true;
			efi = {
				canTouchEfiVariables = true;
			};
		};
		initrd.luks.devices.cryptroot.device = "/dev/disk/by-uuid/3153b379-9bc8-48e0-baa8-5e9ba59db081";
	};
	fileSystems = {
		"/" = {
			device = "cryptroot";
			fsType = "btrfs";
			options = ["subvol=/@"];
		};
		"/home" = {
			device = "cryptroot";
			fsType = "btrfs";
			options = ["subvol=/@home"];
		};
#		"/documents" = {
#			device = "root";
#			fsType = "btrfs";
#			options = "subvol=/@documents";
#		};

		"/boot" = {
			device = "/dev/disk/by-label/BOOT"; # replace with your actual EFI partition UUID
			fsType = "vfat";
		};
	};
}
