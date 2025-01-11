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

  systemd.services = {
    libvirtd.enable = false;
    libvirt-guests.enable = false;
    virtlogd.enable = false;
  };

  # networking.networkmanager.dns = "systemd-resolved";

  # services.resolved = {
    # enable = true;
    # domains = [ "~vm.local" ];  # Direct queries for vm.local to specific DNS
  # };

  # systemd.services."libvirt-resolved" = {
    # description = "Configure systemd-resolved for vm.local";
    # after = [ "network.target" "libvirtd.service" ];
    # wantedBy = [ "multi-user.target" ];
    # serviceConfig.ExecStart = ''
      # ${pkgs.systemd}/bin/resolvectl domain virbr0 '~vm.local'
      # ${pkgs.systemd}/bin/resolvectl dns virbr0 192.168.122.1
    # '';
  # };
}
