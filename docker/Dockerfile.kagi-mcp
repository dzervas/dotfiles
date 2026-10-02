# syntax=docker/dockerfile:1
FROM debian:trixie-slim AS download
ARG TARGETARCH

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# Changes with every release, so a new release invalidates the cached download below.
ADD https://github.com/Microck/kagi-cli/releases/latest/download/release-notes.json /release-notes.json

RUN set -eu; \
    case "$TARGETARCH" in \
      amd64) target=x86_64-unknown-linux-gnu ;; \
      arm64) target=aarch64-unknown-linux-gnu ;; \
      *) printf 'Unsupported architecture: %s\n' "$TARGETARCH" >&2; exit 1 ;; \
    esac; \
    latest=$(curl -fsSLo /dev/null -w '%{url_effective}' --retry 3 \
      https://github.com/Microck/kagi-cli/releases/latest); \
    tag=${latest##*/}; \
    curl -fsSL --retry 3 \
      "https://github.com/Microck/kagi-cli/releases/download/${tag}/kagi-${tag}-${target}" \
      -o /kagi; \
    chmod 0755 /kagi

FROM debian:trixie-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=download /kagi /usr/local/bin/kagi

ENV HOME=/tmp/kagi \
    XDG_CONFIG_HOME=/tmp/kagi/config \
    XDG_CACHE_HOME=/tmp/kagi/cache \
    XDG_DATA_HOME=/tmp/kagi/data

USER 10001:10001
WORKDIR /tmp
ENTRYPOINT ["/usr/local/bin/kagi"]
CMD ["mcp"]

# Built as kagi-mcp:local by docker-mcp-builder.service
# (home/pi-mcp-gateway.nix). One-time setup:
# docker mcp secret set kagi.session_token
# docker mcp profile server add pi --server file://pi-kagi.yaml
# systemctl --user restart pi-mcp-gateway
# docker mcp profile tools pi --disable kagi.kagi_extract --disable kagi.kagi_fastgpt --disable kagi.kagi_enrich_web --disable kagi.kagi_enrich_news --disable kagi.kagi_history_list --disable kagi.kagi_history_stats --disable kagi.kagi_site_pref_list --disable kagi.kagi_assistant_custom_list --disable kagi.kagi_lens_list --disable kagi.kagi_custom_bang_list --disable kagi.kagi_redirect_list --disable kagi.kagi_auth_check
