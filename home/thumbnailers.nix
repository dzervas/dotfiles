{ pkgs, ... }: let
  mkThumbnailer = {name, exec, mime, try-exec ? null}: {
    ".local/share/thumbnailers/${name}.thumbnailer".text = ''
      [Thumbnailer Entry]
      Exec=${exec} %i
      MimeType=${mime}
    '' + (
      if !builtins.isNull try-exec then
        "TryExec=${try-exec}"
      else
        "");
  };
in {
  home = {
    packages = with pkgs; [
      f3d
    ];

    file = mkThumbnailer {
      name = "stl";
      exec = "f3d -fpqat -j --camera-elevation-angle -33 --max-size 10 --resolution 500,500 --output %o %i";
      mime = "model/x.stl-binary;model/x.stl-ascii;model/stl";
    };
  };
}
