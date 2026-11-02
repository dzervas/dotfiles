# Bubblewrap wrapper for a package.
#
# Every user-supplied string (paths, env values, args, extraArgs, home) is placed
# inside double quotes in the generated bash, so `$HOME`, `$PWD` and variables
# defined by `setup` expand at runtime.
#
# Mount order matters for bwrap (later mounts shadow earlier ones):
# base, gpu, extraArgs, home, ro, rw, dev, then whatever `setup` appended to bwrap_extra.
{
  lib,
  bubblewrap,
  coreutils,
  runCommand,
  writeShellApplication,
}: {
  package,
  # null replaces the package: same outputs, but bin/ holds only the sandboxed mainProgram.
  # A string produces a package with only bin/<alias>, to install next to the original.
  alias ? null,
  # Prepended to the program's own arguments
  args ? [],
  # Persistent directory bound over $HOME
  home ? null,
  net ? false,
  # Render nodes, NVIDIA nodes and the driver tree
  gpu ? false,
  # Each entry is a path or { path; try = true; } for a bind that may be missing
  ro ? [],
  rw ? [],
  dev ? [],
  env ? {},
  # A list starts from an empty environment and forwards only these variables when set
  keepEnv ? null,
  unsetEnv ? [],
  # Bash run before bwrap. It may define variables used above, append bwrap
  # arguments to the bwrap_extra array and rewrite "$@".
  setup ? "",
  extraArgs ? [],
}: let
  mainProgram = package.meta.mainProgram or (lib.getName package);
  name = if alias == null then mainProgram else alias;

  quote = s: ''"${s}"'';
  mount = flag: entry: let
    path = entry.path or entry;
    try = entry.try or false;
  in "${flag}${lib.optionalString try "-try"} ${quote path} ${quote path}";

  wrapper = writeShellApplication {
    inherit name;
    text = ''
      bwrap_extra=()
      ${setup}
      ${lib.optionalString (home != null) ''${coreutils}/bin/mkdir -p ${quote home}''}

      bwrap_args=(
        --unshare-all
        ${lib.optionalString net "--share-net"}
        --die-with-parent
        ${lib.optionalString (keepEnv != null) "--clearenv"}
        --proc /proc
        --dev /dev
        --tmpfs /tmp

        --ro-bind /nix/store /nix/store
        --ro-bind /etc/static /etc/static
        --ro-bind /etc/passwd /etc/passwd
        --ro-bind /etc/group /etc/group
        --ro-bind /run/current-system/sw /run/current-system/sw
        --ro-bind "/etc/profiles/per-user/$USER" "/etc/profiles/per-user/$USER"
        ${lib.concatMapStringsSep "\n  " (path: "--ro-bind-try ${path} ${path}") (lib.optionals gpu [
          "/run/opengl-driver"
          "/sys/dev/char"
          "/sys/devices"
        ])}
        ${lib.concatMapStringsSep "\n  " quote extraArgs}
        ${lib.optionalString (home != null) ''--bind ${quote home} "$HOME"''}
        ${lib.concatMapStringsSep "\n  " (mount "--ro-bind") ro}
        ${lib.concatMapStringsSep "\n  " (mount "--bind") rw}
        ${lib.concatMapStringsSep "\n  " (mount "--dev-bind") dev}
        ${lib.concatStringsSep "\n  " (lib.mapAttrsToList (n: v: "--setenv ${n} ${quote v}") env)}
        ${lib.concatMapStringsSep "\n  " (n: "--unsetenv ${n}") unsetEnv}
      )

      ${lib.optionalString (keepEnv != null) ''
        for name in ${lib.escapeShellArgs keepEnv}; do
          if [[ -n "''${!name:-}" ]]; then
            bwrap_args+=(--setenv "$name" "''${!name}")
          fi
        done
      ''}

      ${lib.optionalString gpu ''
        # Render nodes only: card* also exposes modesetting and legacy GEM flink global buffer names
        shopt -s nullglob
        for node in /dev/dri/renderD* /dev/nvidiactl /dev/nvidia[0-9]* /dev/nvidia-uvm /dev/nvidia-modeset; do
          bwrap_args+=(--dev-bind-try "$node" "$node")
        done
        shopt -u nullglob
      ''}

      exec ${lib.getExe bubblewrap} "''${bwrap_args[@]}" "''${bwrap_extra[@]}" -- \
        ${lib.getExe' package mainProgram} ${lib.concatMapStringsSep " " quote args} "$@"
    '';
  };
in if alias != null then
  wrapper
else
  runCommand package.name
  {
    inherit (package) meta;
    passthru.unwrapped = package;
  }
  ''
    mkdir -p $out/bin
    for path in ${package}/*; do
      [[ "$(basename "$path")" == bin ]] || ln -s "$path" $out/
    done
    ln -s ${lib.getExe wrapper} $out/bin/${mainProgram}
  ''
