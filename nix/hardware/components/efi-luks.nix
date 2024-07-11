{ ... }: {
	boot = {
		loader = {
			efi.canTouchEfiVariables = true;
			systemd-boot.enable = true;
		};

		initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "sd_mod" ];
	};
}
