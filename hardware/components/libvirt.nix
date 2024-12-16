{ pkgs, ... }: {
  virtualisation.libvirtd = {
    enable = true;
    parallelShutdown = 5;
    onBoot = "ignore";
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true;
      ovmf = {
        enable = true;
        packages = [(pkgs.OVMF.override {
          secureBoot = true;
          tpmSupport = true;
        }).fd];
      };
    };
  };

  programs.virt-manager.enable = true;
}
