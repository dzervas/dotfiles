{ lib, pkgs, ... }: let
  resolution = "512";
  # Takes a name, command, mime type and tryExec and generates a thumbnailer definition
  mkThumbnailer = {name, exec, mime, tryExec ? null}: {
    ".local/share/thumbnailers/${name}.thumbnailer".text = ''
      [Thumbnailer Entry]
      Exec=${exec}
      MimeType=${mime}
    '' + (if !builtins.isNull tryExec then "TryExec=${tryExec}" else "");
  };
  # Takes a list of attrs and feeds them to mkThumbnailer.
  # Then merges the resulting list of attrs into a single attr
  mkThumbnailerFiles = thumbnailers: lib.mkMerge (map mkThumbnailer thumbnailers);
in {
  home.file = mkThumbnailerFiles [
    {
      name = "scad";
      exec = "${pkgs.openscad}/bin/openscad --imgsize ${resolution},${resolution} -o %o %i";
      mime = "text/x-csrc";
    }
    {
      # TODO: Add step, obj & 3mf support
      name = "stl";
      exec = "${pkgs.f3d}/bin/f3d -fpqat -j --camera-elevation-angle -33 --max-size 10 --resolution ${resolution},${resolution} --output %o %i";
      mime = "model/x.stl-binary;model/x.stl-ascii;model/stl";
    }
  ];
}
