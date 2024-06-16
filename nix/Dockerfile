FROM nixos/nix

# Install NixOS and Home Manager
RUN nix-channel --add https://nixos.org/channels/nixos-23.05 nixos && \
	nix-channel --add https://github.com/nix-community/home-manager/archive/release-23.05.tar.gz home-manager && \
	nix-channel --update && \
	nix-env -iA nixpkgs.nixos-generators nixpkgs.nixos-rebuild nixpkgs.home-manager

# Copy the entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose VNC port
EXPOSE 5900

# Entrypoint script to handle configuration mounting and building
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
