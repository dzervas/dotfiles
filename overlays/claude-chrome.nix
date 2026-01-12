{ lib, stdenv, symlinkJoin, makeWrapper, ungoogled-chromium, fetchurl, writeTextFile, lndir, unzip }:

let
  extensionId = "fcoeoabgfenejglbffodgkkbkcdhcgfn";
  extensionVersion = "1.0.36";

  icon = fetchurl {
    url = "https://upload.wikimedia.org/wikipedia/commons/8/8a/Claude_AI_logo.svg";
    hash = "sha256-jU40fVilK6GiHyn7GclKlVtL87jpVs5O6leU/bqnK4A=";
  };

  # Download Claude extension CRX from Chrome Web Store update server
  claudeExtensionCrx = fetchurl {
    url = "https://clients2.google.com/service/update2/crx?response=redirect&acceptformat=crx2,crx3&prodversion=143.0.7499.169&x=id%3D${extensionId}%26uc";
    hash = "sha256-oKtCxdMXgIqioAZ2EF1kSsp2YW/2U5IZuIAHdn4M0E0=";
  };

  # Extract CRX to unpacked extension directory
  claudeExtension = stdenv.mkDerivation {
    name = "claude-extension-${extensionVersion}";
    src = claudeExtensionCrx;
    nativeBuildInputs = [ unzip ];
    unpackPhase = "unzip -q $src || true";  # CRX3 has extra bytes, ignore warning
    installPhase = ''
      mkdir -p $out
      cp -r . $out/
      # Remove update_url from manifest to prevent unwanted updates
      sed -i '/"update_url"/d' $out/manifest.json
    '';
  };

  desktopFile = writeTextFile {
    name = "claude-chrome.desktop";
    destination = "/share/applications/claude-chrome.desktop";
    text = ''
      [Desktop Entry]
      Version=1.0
      Name=Claude Chrome
      GenericName=Web Browser
      Comment=Access Claude with Chromium
      Exec=chromium %U
      Terminal=false
      Icon=claude-chrome
      Type=Application
      Categories=Network;WebBrowser;
      MimeType=text/html;text/xml;application/xhtml+xml;application/vnd.mozilla.xul+xml;text/mml;x-scheme-handler/http;x-scheme-handler/https;
      StartupNotify=true
      StartupWMClass=chromium-browser
    '';
  };
in
symlinkJoin {
  name = "claude-chrome";
  paths = [ ungoogled-chromium ];
  nativeBuildInputs = [ lndir makeWrapper ];
  postBuild = ''
    # Replace desktop entry
    rm $out/share/applications
    mkdir -p $out/share/applications
    cp ${desktopFile}/share/applications/claude-chrome.desktop $out/share/applications/

    # Replace icons
    rm $out/share/icons
    mkdir -p $out/share/icons
    ${lndir}/bin/lndir -silent ${ungoogled-chromium}/share/icons $out/share/icons
    mkdir -p $out/share/icons/hicolor/scalable/apps
    cp ${icon} $out/share/icons/hicolor/scalable/apps/claude-chrome.svg

    # Wrap chromium binary to load Claude extension
    rm $out/bin/chromium
    makeWrapper ${ungoogled-chromium}/bin/chromium $out/bin/chromium \
      --add-flags "--load-extension=${claudeExtension}"

    # Update chromium-browser symlink
    rm $out/bin/chromium-browser
    ln -s $out/bin/chromium $out/bin/chromium-browser
  '';
}
