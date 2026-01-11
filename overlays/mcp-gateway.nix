# nix-update:mcp-gateway
{ lib
, buildGoModule
, fetchFromGitHub
}: buildGoModule rec {
  pname = "mcp-gateway";
  version = "0.35.0";

  src = fetchFromGitHub {
    owner = "docker";
    repo  = "mcp-gateway";

    # gha-updater: DATA=$(curl "https://api.github.com/repos/docker/mcp-gateway/tags?per_page=1" | jq ".[]") DLURL=$(echo "$DATA" | jq -r .tarball_url) VERSION=$(echo "$DATA" | jq -r .name) echo -n "$VERSION $(nix-prefetch-url $DLURL)"
    rev   = "v${version}";
    hash  = "sha256-xdw0ZTSgOk5l8x7zSQ9kPJuqFUOz0cmeU80q1VVWsY8=";
  };

  vendorHash = null;
  subPackages = [ "cmd/docker-mcp" ];

  ldflags = [
    "-s" "-w"
    "-X github.com/docker/mcp-gateway/cmd/docker-mcp/version.Version=${version}"
  ];

  # Tests likely aren’t relevant for the CLI build; flip to true if the repo has them wired up.
  doCheck = false;

  meta = with lib; {
    description = "Gateway for the Model Context Protocol (MCP) by Docker";
    homepage = "https://github.com/docker/mcp-gateway";
    license = licenses.asl20;
    mainProgram = "docker-mcp";
    maintainers = [];
    platforms = platforms.unix;
  };
}
