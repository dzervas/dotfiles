{
  stdenv,
  makeDesktopItem,
  writeScript,
  nodejs_18,
  electron-bin,
  zenity,
  git,
}: let
  node = nodejs_18;
  electron = electron-bin;
  source-dir = "~/.local/OpenNoodl";
in stdenv.mkDerivation rec {
  pname = "opennoodl";
  version = "0.1.0";
  unpackPhase = "true"; # We don't have a source
  doCheck = false;

  checkScript = writeScript "checks" ''
    function check_dir() {
      local dir="$1"
      local cmd="$2"
      local msg="$3"

      if [ -d "$dir" ]; then
        return 0
      fi

      ${zenity}/bin/zenity --forms --width 400 \
        --title "Noodl Editor" \
        --text "$msg\n\nShould I run: <span font='monospace'>$cmd</span>?"

      if [ $? -ne 0 ]; then
        exit 1
      fi

      eval $cmd || exit $?
    }

    check_dir ${source-dir} "${git}/bin/git clone https://github.com/The-Low-Code-Foundation/OpenNoodl ${source-dir}" "The OpenNoodl source folder couldn't be found"
    check_dir ${source-dir}/node_modules "${node}/bin/npm ci --prefix ${source-dir}" "The dependencies are not installed"
    check_dir ${source-dir}/packages/noodl-editor/dist/linux-unpacked "export BUILD_AS_DIR=1 && ${node}/bin/npm run build:editor:_viewer --prefix ${source-dir} && ${node}/bin/npm run build:editor:_editor --prefix ${source-dir}" "The Noodl Editor is not built"
  '';

  editorScript = writeScript "opennoodl-editor" ''
    # Makes noodl search under this dir for bin/git and uses it instead of the downloaded git binary
    export LOCAL_GIT_DIRECTORY="${git}"
    ${checkScript} && \
    exec ${electron}/bin/electron ${source-dir}/packages/noodl-editor/dist/linux-unpacked/resources/app.asar
  '';

  # Create desktop items using makeDesktopItem
  editorDesktop = makeDesktopItem {
    name = "opennoodl-editor";
    exec = "${editorScript}";
    icon = builtins.fetchurl {
      # gha-updater: nix-prefetch-url https://github.com/The-Low-Code-Foundation/OpenNoodl/raw/refs/heads/main/packages/noodl-editor/build/icons/512x512.png
      url = "https://github.com/The-Low-Code-Foundation/OpenNoodl/raw/refs/heads/main/packages/noodl-editor/build/icons/512x512.png";
      sha256 = "0vf8qfpwyzxd5pj7b7ff0lzlmqhlmkpaf9jm6rzxwgas41b29r6n";
    };
    desktopName = "OpenNoodl Editor";
    categories = [ "Development" ];
  };

  installPhase = ''
    mkdir -p $out/share/applications
    cp ${editorDesktop}/share/applications/${editorDesktop.name} $out/share/applications/
    mkdir -p $out/bin
    cp ${editorScript} $out/bin/${editorScript.name}
  '';
}
