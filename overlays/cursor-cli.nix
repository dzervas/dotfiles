{pkgs, ...}: pkgs.stdenv.mkDerivation rec {
  pname = "cursor-cli";

  src = pkgs.fetchurl {
    # gha-updater: DLURL=$(curl https://cursor.com/install -fsS | rg '^DOWNLOAD_URL' | rg -o "https://.+.tar.gz") echo -n "$DLURL $(nix-prefetch-url $DLURL)"
    url = "https://downloads.cursor.com/lab/${version}/linux/x64/agent-cli-package.tar.gz";
    hash = "sha256-ikoxUvpLMngDOlHawq7i69mOcPGkV8q1capDU83QMWs=";
  };
  version = "2025.08.08-f57cb59";

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
  ];

  buildInputs = with pkgs; [
    stdenv.cc.cc.lib
    glibc
    zlib
    openssl
    curl
    libsecret
    gtk3
    glib
    nspr
    nss
    at-spi2-atk
    cups
    dbus
    libdrm
    libxkbcommon
    mesa
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Extract the archive
    mkdir -p $out/lib/cursor-cli
    tar -xzf $src -C $out/lib/cursor-cli --strip-components=1

    # Create bin directory
    mkdir -p $out/bin

    # Create a wrapper script for cursor
    cat > $out/bin/cursor << 'EOF'
    #!/usr/bin/env bash
    set -euo pipefail
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")/../lib/cursor-cli"
    exec "$SCRIPT_DIR/cursor-agent" "$@"
    EOF
    chmod +x $out/bin/cursor

    # Install additional binaries that might be needed
    if [ -f $out/lib/cursor-cli/node ]; then
    cp $out/lib/cursor-cli/node $out/bin/cursor-node
    chmod +x $out/bin/cursor-node
    fi

    if [ -f $out/lib/cursor-cli/rg ]; then
    cp $out/lib/cursor-cli/rg $out/bin/cursor-rg
    chmod +x $out/bin/cursor-rg
    fi

    runHook postInstall
    '';

  meta = with pkgs.lib; {
    description = "Cursor CLI - AI-powered code editor command line interface";
    homepage = "https://cursor.com";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    maintainers = with maintainers; [ ];
    mainProgram = "cursor";
  };
}
