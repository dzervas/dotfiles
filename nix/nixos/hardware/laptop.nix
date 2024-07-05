{ config, lib, pkgs, ... }:

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
	boot.initrd.kernelModules = [ "amdgpu" ];
	boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "sd_mod" ];
	nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
	hardware.cpu.amd.updateMicrocode = true;
	services.xserver.videoDrivers = [ "modesetting" ];
	boot.kernelModules = [ "kvm-amd" ];
	boot.extraModulePackages = [ ];
	services.libinput.enable = true;
	services.libinput.touchpad.tapping = true;
	services.libinput.touchpad.tappingDragLock = true;
	hardware.enableRedistributableFirmware = true;
	hardware.amdgpu.initrd.enable = true;
	# boot.kernelParams = ["radeon.si_support=0" "amdgpu.si_support=1"];
	hardware.graphics.extraPackages = with pkgs; [
  	mesa
  	rocmPackages.clr.icd
	];

	fileSystems = {
		"/" = {
			device = "/dev/disk/by-uuid/554c3697-ff49-4f1c-af96-69624a12910b";
			fsType = "btrfs";
			options = ["subvol=root"];
		};
		"/home" = {
			device = "/dev/disk/by-uuid/554c3697-ff49-4f1c-af96-69624a12910b";
			fsType = "btrfs";
			options = ["subvol=home"];
		};
		"/nix" = {
			device = "/dev/disk/by-uuid/554c3697-ff49-4f1c-af96-69624a12910b";
			fsType = "btrfs";
			options = ["subvol=nix"];
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
