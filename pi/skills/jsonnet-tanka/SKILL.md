---
name: jsonnet-tanka
description: Jsonnet and Tanka conventions for this homelab. Use when deploying a new app to the cluster, editing anything under envs/ or lib/, adding a helm chart, or extending labsonnet.
---

# Jsonnet & Tanka in this homelab

Every env is `envs/<name>/{spec.json,main.jsonnet}`, rendered by Tanka. The goal is always the smallest, most boring jsonnet that looks like it was written next to its siblings.

## Deploying a new app

1. **Find the sibling.** Before writing anything, locate the existing env with the same shape and read it end to end:
   - labsonnet VPN app: `envs/atuin`, `envs/pi-web`, `envs/openhands`
   - labsonnet with extra resources: `envs/cliproxyapi`, `envs/rclone`, `envs/forgejo`
   - helm chart: `envs/traefik`, `envs/external-dns`, `envs/cloudnative-pg`
   - multi-component: `envs/n8n` (`main.jsonnet` only composes `./*.libsonnet` with `+`)

   Done when you can name the sibling you are copying.

2. **Pick the source, in this order.** Research upstream (docs, repo, chart source) before deciding, and state the verdict with its reason:
   1. A jsonnet library (`jsonnetfile.json`, `jsonnet-libs/*`) for the resources or CRDs.
   2. A **published** helm chart, vendored with `tk-chart-add <repo-url> <repo-name> <chart> <version>` and rendered with `helm.template(name, '../../charts/<chart>', { namespace, values })`.
   3. labsonnet (`lib/labsonnet.libsonnet`) on the bare image.

   A chart is disqualified when it is unpublished (source-only in a git repo), license-gated, drags in a stack the cluster already has (Keycloak, Postgres, Redis), or needs the Docker socket. When you fall back to labsonnet from a real chart, **mirror the chart**: read its `values.yaml` and templates and carry over image + `appVersion` tag, UID/fsGroup, ports, required env, and persisted paths. Verify the tag exists and has amd64+arm64 via the registry API.

3. **Write the env.** Copy the sibling's `spec.json`, changing only `metadata.name` and `spec.namespace`. Write `main.jsonnet` per the style reference below.

4. **Wire networking.** See the networking reference. Done when every inbound and outbound path the app needs is accounted for, with the label or policy that allows it.

5. **Verify** (see the verification reference), then hand the user the apply commands. Applying is the user's call.

## Extending labsonnet

Extend only when the sibling pattern cannot express the need. Keep the change **surgical**:

- **Where**: `lib/labsonnet` is a separate repo (`github.com/dzervas/labsonnet`) for generic workload building. Anything tied to this cluster (the Traefik gateway, magicentry, 1Password, VPN CIDRs) goes in the wrapper `lib/labsonnet.libsonnet`.
- **Shape**: add an optional named argument defaulting to `null` to the existing `with*` function (`withVpnHttp(port, fqdn, cidrs=null, name=null, magicentry=null)`) rather than a parallel function. Existing callers must render byte-identical.
- **Single source of truth**: a definition used in two places (e.g. the magicentry forwardAuth middleware) moves to `lib/helpers/<thing>.libsonnet` and both the env and the wrapper import it.
- **Latent bugs**: when your change runs through buggy code, fix the bug, prove existing callers are unaffected, and call it out to the user.
- Remove TODOs your change resolves.

## Style reference

**File skeleton**, top to bottom, each group separated by a blank line:
1. Imports (jsonnetfmt sorts each contiguous block).
2. Builder aliases: `local networkPolicy = k.networking.v1.networkPolicy;`, `local helm = tk.helm.new(std.thisFile);`
3. Constants: `local namespace = '...';`, `local domain = '...';`, `local image = '...';`
4. The body: a bare `lab.new(...) + ...` chain for a single-app env; a top-level object with camelCase keys (`cliproxyapi:`, `networkPolicy:`) when there is more than one resource.

**labsonnet chains** read as one `+`-chain per app: `new`, namespace, `withType`, identity/labels, PVs, routes, secrets, `withEnv` last. Follow the sibling when it differs.

**Env maps** are one `withEnv({...})` with string values, grouped by concern with blank lines between groups, and `TZ: timezone` (from `helpers/timezone.libsonnet`) in every app.

**Builders over literals**: use `k.libsonnet`, `external-secrets.libsonnet`, `gateway-api.libsonnet`, `cilium-libsonnet` builders (`networkPolicy.new(...) + networkPolicy.spec.withIngress([...])`). Raw objects are for CRDs with no library (Traefik `Middleware`).

**Helm envs**: values inline in `helm.template`, reusing `helpers/ingress.libsonnet` and `helpers/affinity.libsonnet`. Drop unwanted chart output with `+ { pod_x_test_connection: {} }`; patch rendered resources with `+:`.

**Minimal by default**: labsonnet's defaults stand. Resources, probes, replicas and knobs appear only when the app or the user needs them.

**Secrets** come from 1Password through `lab.withOpEnvs(...)` or an `ExternalSecret`; generated configs use `std.manifestJsonEx` / `std.manifestYamlDoc`; shell scripts use `|||` blocks.

**Comments** carry the *why* and the gotcha, in one or two short lines, capitalized, usually without a trailing period: the upstream constraint, the reason for a workaround, a pointer to the related env (`see envs/cliproxyapi networkPolicy`), an upstream issue number. Commented-out alternatives stay with their reason (`// Broken: Operation not permitted on /data`). Code documents itself; there are no README or doc files per env.

## Networking reference

- A Cilium clusterwide policy (`envs/network`) denies ingress from other namespaces by default; same-namespace traffic is allowed.
- Every new namespace needs `tk-ns apply envs/network` once to get its `default-ns-allow` policy.
- **Opt-in labels** grant cross-namespace access through the target's policy: `ai/enable: 'true'` reaches cliproxyapi, `magicentry.rs/enable: 'true'` registers with magicentry. Prefer adding the label over writing a new policy.
- `lab.withVpnHttp(port, fqdn)` routes through Traefik's `websecure-vpn` listener; `lab.withPublicHttp` through `websecure`. VPN hosts live under `*.vpn.dzerv.art`.
- In-cluster callers use service DNS (`http://svc.ns.svc:port`). CoreDNS resolves `*.vpn.dzerv.art` to Traefik's VPN IP `10.43.0.50`, so the external name hairpins through Traefik and its auth.
- Gateway API `ExtensionRef` filters only resolve Traefik middlewares in the route's own namespace, so labsonnet apps get their own middleware copy (`lib/helpers/magicentry.libsonnet`).
- magicentry forwardAuth matches the origin built from `X-Forwarded-Proto`, which is `wss` for websocket upgrades: `auth_url_origins` needs both `https://` and `wss://`.

## Verification reference

The cluster is often unreachable from the agent; render-level proof is the bar.

- `tk show envs/<name> --dangerous-allow-redirect` renders cleanly, and you read the output for the resources you expect.
- `jsonnetfmt --test` passes on every touched file.
- Touching `lib/` means diffing every env that uses it against the parent revision. Copy the tree with `tar` (excluding `.jj`, `.git`, `.devenv`), overwrite the touched files with `jj file show -r @- <path>`, delete new files, and compare `tk show | sha1sum` per env. Every env must be byte-identical except the one you meant to change.
- Report what was verified and what remains unverified (nothing applied, no live traffic tested).

**IMPORTANT** NEVER do `tk apply` or other potentially destructive operations to the cluster, unless the user has specifically told you or agreed to
