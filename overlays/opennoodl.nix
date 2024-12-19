{
  stdenv,
  fetchFromGitHub,
  makeDesktopItem,
  writeScript,
  nodejs_18,
  # nodePackages,
}: stdenv.mkDerivation rec {
  src = fetchFromGitHub {
    owner = "The-Low-Code-Foundation";
    repo = "OpenNoodl";

    # TODO: Fix this
    # gha-updater: VERSION="$(curl https://api.github.com/repos/The-Low-Code-Foundation/OpenNoodl/tags | jq -r '. | first | .name')" && echo -n "$VERSION $(nix-prefetch-url --unpack https://github.com/noodlapp/noodl/archive/refs/tags/$VERSION.zip)"
    rev = "release";
    hash = "sha256-vOfMZKg6KVHf1HzS/V7Qy0j9t99hY5Gd7Aua08O9t4M=";
  };

  pname = "opennoodl";
  version = src.rev;

  nativeBuildInputs = [ nodejs_18 ];
  # targetPkgs = nativeBuildInputs ++ [
  #   nodePackages.lerna
  # ];
  # buildInputs = nativeBuildInputs ++ [
  #   nodePackages.lerna
  # ];

  # We won't do a traditional build because this is a runtime environment setup
  # buildPhase = "true";

  # Create editor script
  editorScript = writeScript "${pname}-editor" ''
#!/usr/bin/env bash
cd @@OUT@@/src
export PATH=node_modules/.bin:$PATH
npm run start:editor
'';

  # Create viewer script
  viewerScript = writeScript "${pname}-viewer" ''
#!/usr/bin/env bash
cd @@OUT@@/src
export PATH=node_modules/.bin:$PATH
npm run start:viewer
'';

  # doCheck = false;

  # Create desktop items using makeDesktopItem
  editorDesktop = makeDesktopItem {
    name = "noodle-editor";
    exec = editorScript;
    # icon = "$out/packages/noodl-editor/build/icons/1024x1024.png";
    desktopName = "Noodle Editor";
    categories = [ "Development" ];
  };

  viewerDesktop = makeDesktopItem {
    name = "noodle-viewer";
    exec = viewerScript;
    # icon = "$out/packages/noodl-editor/build/icons/1024x1024.png";
    desktopName = "Noodle Viewer";
    categories = [ "Development" ];
  };

  # buildPhase = ''
  #   cd ${src}
  #   npm install
  # '';

  # buildPhase = ''
  #   runHook preBuild
  #   cp -r ${src} $TMPDIR/build
  #   cd $TMPDIR/build
  #   npm config set cache $TMPDIR/npm-cache --global
  #   npm ci --no-fund --no-audit
  #   runHook postBuild
  # '';

  installPhase = ''
    # mkdir -p $out/lib/node_modules
    # cd $out/lib/node_modules
    mkdir -p $out/src
    cp -r ${src}/* $out/src
    chmod -R u+w $out/src

    cd $out/src
    echo "Log file: $out/npm-install.log" > /dev/stderr
    npm install --no-fund --no-audit --no-bin-links --ignore-scripts --omit=dev --legacy-peer-deps --cache $out/cache 2>&1 | tee $out/npm-install.log
    ls -lah $out/src

    # Create symlink to the deployed executable folder
    ln -s $out/lib/node_modules/.bin $out/bin

    # Fixup all executables
    ls $out/bin/* | while read i
    do
        file="$(readlink -f "$i")"
        chmod u+rwx "$file"
        if isScript "$file"
        then
            sed -i 's/\r$//' "$file"  # convert crlf to lf
        fi
    done

    # runHook preInstall
    # mkdir -p $out/bin

    # Install the editor script
    # mkdir -p $out/src
    # cp -r ${src}/* $out/src
    # cd $out/src
    # npm install --no-fund --no-audit --prefix $out/src
    # mkdir -p $out/src
    # cp -r . $out/src
    # cp -r $TMPDIR/build $out/src

    cp ${editorScript} $out/bin/noodle-editor
    sed -i "s|@@OUT@@|$out|g" $out/bin/noodle-editor
    chmod +x $out/bin/noodle-editor

    # Install the viewer script
    cp ${viewerScript} $out/bin/noodle-viewer
    sed -i "s|@@OUT@@|$out|g" $out/bin/noodle-viewer
    chmod +x $out/bin/noodle-viewer

    mkdir -p $out/share/applications
    cp ${editorDesktop}/share/applications/noodle-editor.desktop $out/share/applications/
    cp ${viewerDesktop}/share/applications/noodle-viewer.desktop $out/share/applications/

    runHook postInstall
  '';

  # desktop = stdenv.mkDerivation {
  #   pname = "${pname}-desktop";
  #   version = "${version}";
  #   dontUnpack = true;
  #   buildPhase = "true";
  #   installPhase = ''
  #     mkdir -p $out/share/applications
  #     cp ${editorDesktop}/share/applications/noodle-editor.desktop $out/share/applications/
  #     cp ${viewerDesktop}/share/applications/noodle-viewer.desktop $out/share/applications/
  #   '';
  # };

  # Create separate derivations for the desktop entries.
  # We'll produce desktop files into a separate output.
  # outputs = [ "out" "desktop" ];
}
