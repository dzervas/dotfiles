_final: prev:
prev.openvpn.overrideAttrs (prevAttrs: rec {
  pname = "openvpn-aws";
  patches = (prevAttrs.patches or []) ++ [
    # From https://github.com/samm-git/aws-vpn-client/blob/master/openvpn-v2.6.12-aws.patch
    ./openvpn-aws-v2.6.12.patch
  ];

  script = ./connect.sh;

  # install an extra binary named openvpn-aws (and its manpage symlink)
  postInstall = (prevAttrs.postInstall or "") + ''
    # Some nixpkgs versions put it in $out/sbin; normalize:
    if [ -x "$out/sbin/openvpn" ]; then
      mkdir -p "$out/bin"
      mv "$out/sbin/openvpn" "$out/bin/openvpn"
    fi

    mv "$out/bin/openvpn" "$out/bin/openvpn-aws"
    cp "${script}" $out/bin/openvpn-aws-connect
    chmod +x $out/bin/openvpn-aws-connect

    # Man page (if present)
    if [ -e "$out/share/man/man8/openvpn.8.gz" ]; then
      mv "openvpn.8.gz" "$out/share/man/man8/openvpn-aws.8.gz" || true
    fi
  '';

  # so `nix run .#openvpn-aws` picks the right binary
  meta = (prevAttrs.meta or {}) // { mainProgram = "openvpn-aws"; };
})
