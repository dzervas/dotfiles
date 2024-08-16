{ pkgs, ... }: let
  resolution = "500";
  mkThumbnailer = {name, exec, mime, tryExec ? null}: {
    ".local/share/thumbnailers/${name}.thumbnailer".text = ''
      [Thumbnailer Entry]
      Exec=${exec}
      MimeType=${mime}
    '' + (
      if !builtins.isNull tryExec then
        "TryExec=${tryExec}"
      else
        "");
  };
in {
  home = {
    packages = with pkgs; [
      f3d
      openscad
    ];

    file = mkThumbnailer {
      name = "stl";
      exec = "f3d -fpqat -j --camera-elevation-angle -33 --max-size 10 --resolution ${resolution},${resolution} --output %o %i";
      mime = "model/x.stl-binary;model/x.stl-ascii;model/stl";
    } // mkThumbnailer {
      name = "scad";
      exec = "openscad --imgsize ${resolution},${resolution} -o %o %i";
      mime = "text/x-csrc";
    };
  };
}
