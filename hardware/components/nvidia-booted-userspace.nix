# NVIDIA does not allow userspace to have a different version than the currently loaded driver
# so normal rebuilds fail. On boot, softlink the userspace libs to a predefined path so that they
# get auto-updated after a rebuild & reboot
{
  config,
  lib,
  pkgs,
  ...
}: let
  graphics = config.hardware.graphics;
  toolkit = config.hardware.nvidia-container-toolkit;
  executables = [
    "nvidia-cuda-mps-control"
    "nvidia-cuda-mps-server"
    "nvidia-debugdump"
    "nvidia-powerd"
    "nvidia-smi"
  ];
  bootedTools = pkgs.symlinkJoin {
    name = "booted-nvidia-tools";
    paths = map (name: pkgs.writeShellScriptBin name ''
      exec /run/nvidia-booted-bin/bin/${name} "$@"
    '') executables;
  };
  drivers = pkgs.buildEnv {
    name = "booted-graphics-drivers";
    paths = [ graphics.package ] ++ graphics.extraPackages;
  };
  drivers32 = pkgs.buildEnv {
    name = "booted-graphics-drivers-32bit";
    paths = [ graphics.package32 ] ++ graphics.extraPackages32;
  };
  generator = pkgs.callPackage "${pkgs.path}/nixos/modules/services/hardware/nvidia-container-toolkit/cdi-generate.nix" {
    inherit (toolkit) csv-files device-name-strategy discovery-mode mounts disable-hooks enable-hooks extraArgs;
    nvidia-container-toolkit = toolkit.package;
    # The generator only uses the driver's lib output for its search path.
    nvidia-driver.lib = "/run/opengl-driver";
  };
  checkedGenerator = pkgs.writeShellScript "nvidia-booted-cdi-generator" ''
    set -eu
    module_version=$(${pkgs.gnugrep}/bin/grep -oE '[0-9]{3}\.[0-9]+(\.[0-9]+)?' /proc/driver/nvidia/version | ${pkgs.coreutils}/bin/head -n 1)
    library=$(${pkgs.coreutils}/bin/readlink -f /run/opengl-driver/lib/libnvidia-ml.so.1)
    library_version=''${library##*libnvidia-ml.so.}
    if [ "$module_version" != "$library_version" ]; then
      echo "NVIDIA module $module_version does not match active NVML $library_version" >&2
      exit 1
    fi
    export PATH=/run/nvidia-booted-bin/bin:$PATH
    ${lib.getExe generator}
    # The generated library mounts can contain symlinks into this store output.
    # Make the matching booted output available at the same path in containers.
    driver_lib=$(${pkgs.coreutils}/bin/dirname "$(${pkgs.coreutils}/bin/dirname "$library")")
    spec="$RUNTIME_DIRECTORY/nvidia-container-toolkit.json"
    temp=$(${pkgs.coreutils}/bin/mktemp "$RUNTIME_DIRECTORY/.nvidia-cdi.XXXXXX")
    trap '${pkgs.coreutils}/bin/rm -f "$temp"' EXIT
    ${pkgs.jq}/bin/jq --arg driver_lib "$driver_lib" \
      '.containerEdits.mounts[.containerEdits.mounts | length] = {hostPath: $driver_lib, containerPath: $driver_lib, options: ["ro", "nosuid", "nodev", "bind"]}' \
      "$spec" > "$temp"
    # Rootless Podman must be able to read the generated CDI specification.
    ${pkgs.coreutils}/bin/chmod 0644 "$temp"
    ${pkgs.coreutils}/bin/mv "$temp" "$spec"
  '';
in {
  # Keep the actual graphics driver environments reachable from the booted system.
  system.systemBuilderCommands = ''
    ln -s ${drivers} $out/graphics-drivers
    ln -s ${lib.getBin config.hardware.nvidia.package} $out/nvidia-bin
    ${lib.optionalString graphics.enable32Bit "ln -s ${drivers32} $out/graphics-drivers-32"}
  '';

  # The stock tmpfiles rules replace these links with the new generation on switch.
  # Point them at the booted generation during activation instead.
  systemd.tmpfiles.settings.graphics-driver = lib.mkForce {};
  system.activationScripts.bootedGraphicsDrivers.text = ''
    link_booted_graphics() {
      local path="$1" generation_link="$2" target="" type rule_path mode user group age rule_target
      if [ -e "$generation_link" ]; then
        target="$generation_link"
      elif [ -f /run/booted-system/etc/tmpfiles.d/graphics-driver.conf ]; then
        # Older generations have no graphics-drivers link; recover their original
        # graphics environment from the tmpfiles rule that installed it.
        while read -r type rule_path mode user group age rule_target; do
          if [ "$rule_path" = "'$path'" ]; then
            target="$rule_target"
            break
          fi
        done < /run/booted-system/etc/tmpfiles.d/graphics-driver.conf
      fi
      if [ -n "$target" ]; then
        ln -sfnT "$target" "$path.tmp"
        mv -Tf "$path.tmp" "$path"
      else
        echo "Cannot find the booted graphics environment for $path" >&2
      fi
    }
    link_booted_graphics /run/opengl-driver /run/booted-system/graphics-drivers
    ${lib.optionalString graphics.enable32Bit ''
      link_booted_graphics /run/opengl-driver-32 /run/booted-system/graphics-drivers-32
    ''}
    if [ -e /run/booted-system/nvidia-bin ]; then
      bin=/run/booted-system/nvidia-bin
    else
      # Before this module's first boot, the old generation only exposes the
      # driver tools through its system PATH.
      old_smi=$(readlink -f /run/booted-system/sw/bin/nvidia-smi)
      bin=$(dirname "$(dirname "$old_smi")")
    fi
    ln -sfnT "$bin" /run/nvidia-booted-bin.tmp
    mv -Tf /run/nvidia-booted-bin.tmp /run/nvidia-booted-bin
  '';

  # The stock NVIDIA tools have a RUNPATH pointing directly at their own
  # generation's libraries, so /run/opengl-driver alone does not fix them.
  environment.systemPackages = [ (lib.hiPrio bootedTools) ];

  # Upstream's default mounts and generator embed the new package's store paths.
  hardware.nvidia-container-toolkit.mounts = lib.mkForce (
    [
      {
        hostPath = "/run/opengl-driver";
        containerPath = pkgs.addDriverRunpath.driverLink;
      }
    ]
    ++ lib.optionals toolkit.mount-nvidia-docker-1-directories [
      {
        hostPath = "/run/opengl-driver/lib";
        containerPath = "/usr/local/nvidia/lib";
      }
      {
        hostPath = "/run/opengl-driver/lib";
        containerPath = "/usr/local/nvidia/lib64";
      }
    ]
    ++ [
      {
        hostPath = "${lib.getLib pkgs.glibc}/lib";
        containerPath = "${lib.getLib pkgs.glibc}/lib";
      }
      {
        hostPath = "${lib.getLib pkgs.glibc}/lib64";
        containerPath = "${lib.getLib pkgs.glibc}/lib64";
      }
    ]
    ++ lib.optionals toolkit.mount-nvidia-executables (map (name: {
      hostPath = "/run/nvidia-booted-bin/bin/${name}";
      containerPath = "/usr/bin/${name}";
    }) executables)
  );

  systemd.services.nvidia-container-toolkit-cdi-generator.serviceConfig.ExecStart = lib.mkForce (toString checkedGenerator);
}
