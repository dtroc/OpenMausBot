# Maus MVP deployment

Status: SSH deployment and basic network checks have been exercised by the operator.
Cloudflare ingress is prepared but its parser and end-to-end checks remain pending. This document
intentionally contains no inventory or observed configuration of the operator host.

## Components

`compose.maus-mvp.yaml` is a separate deployment definition; the upstream Compose
is unchanged. `omb` extends a pinned upstream image with an exact Codex CLI version.
It does not rebuild the application from this fork's TypeScript source. Updating
the fork and updating the runtime image are separate operations.

Caddy provides a private SSH UI and an optional Cloudflare ingress while preserving the harness loopback
listener. `Caddy.Dockerfile` derives from the pinned official image and removes
its executable's `cap_net_bind_service` file capability during build. Caddy uses
a high port, so it does not need this capability. Keeping the file capability
with a runtime `cap_drop: ALL` bounding set can cause execution to fail with
`operation not permitted`. Runtime user, capability drop and no-new-privileges
remain unchanged; validate the derived image, not the upstream base image. Squid permits CONNECT on the TLS port to exact OpenAI hosts, denies
private destinations, and listens only on the internal network. Squid's file
descriptor limit and its container soft/hard `nofile` limits are all 1024, avoiding
large startup allocations inherited from host defaults while retaining the memory
ceiling. Measure actual proxy memory use after deployment. It is not a TLS
interception proxy. CONNECT filtering controls hosts and ports, not encrypted
paths or content. Data given to agents can reach the authorized LLM provider.

The agent has one writable state mount and one read-only market-data mount. The
proxy configurations are not mounted inside the agent. This deployment has no
Docker socket, host network, host SSH keys, deployment tokens or broker tools.
OptionData export is a subsequent step; no exporter is implemented in this change.

## Preparation gates

Before deploying, the operator must provision the two external networks declared
in Compose, check for subnet/address conflicts, disable IPv6 for them, and enforce
host and forwarding firewall restrictions. A Compose network by itself does not
protect the host. The proxy must not function as a router. Verify actual Docker
rules and test prohibited connections from disposable containers.

Prepare the declared state paths on a dedicated size-limited filesystem and verify
it is mounted before each start. A regular host directory is not a disk quota.
Use the `maus` UID/GID from the selected image for state ownership; do not guess its
numeric ID. The market-data directory belongs to the exporter and is read-only to
agents. Missing bind sources must fail rather than be created automatically.

The firewall must be effective before starting containers. A service ordered after
Docker is not an atomic firewall-before-container-start guarantee. Containers use
manual restart policy. Stop them before Docker restarts or host firewall changes;
reapply and test isolation before manually starting them again. No automatic
restart/deploy workflow is validated. Containers share a host kernel and do not
provide an absolute virtual-machine boundary.

## Coolify

### Proxy network discovery: version-specific compatibility

Coolify 4.3.19 Raw deployments still add management metadata. Its proxy network
reconciliation selects containers with `coolify.managed=true` and attaches the
shared proxy to their networks, including external networks. Raw mode and no
public domain alone do not establish the intended network separation.

Each service therefore declares the valid Compose key-only label
`- coolify.managed` (empty value), plus `- traefik.enable=false`. In the inspected
4.3.19 `Application::oldRawParser`, the exact key-only entry prevents insertion of
`coolify.managed=true`; the proxy's exact-value selector then excludes it. Keep
this list representation: substituting a map or `coolify.managed=false` does not
have the same parser behavior in that version. This is version-specific metadata
compatibility, not an official general-purpose Coolify network isolation feature.
No Coolify application code, permissions or host-wide proxy settings are changed.

Manual deployment cleanup uses the separate applicationId label in the inspected
version, which remains generated. Automatic status/monitoring that depends on
managed=true may not report these containers correctly; inspect Docker state.
Before deployment, remove obsolete containers of this application that still have
managed=true, and detach the shared proxy from this application's two dedicated
networks only. After recreation, verify the effective managed label is empty and
that the shared proxy remains absent after background reconciliation. Revalidate
all of this after any Coolify update, before supplying agent credentials. If the
parser changes or the proxy returns, stop this stack and use an independently
managed Compose deployment instead of weakening network isolation.

Sources: Docker Compose services/labels reference, and Coolify tag v4.3.19:
`app/Models/Application.php`, `bootstrap/helpers/proxy.php`, and
`bootstrap/helpers/docker.php`.


Use the review branch, base directory `/`, and Compose location
`/compose.maus-mvp.yaml`. Select Raw Compose, isolated network only, manual
deployments, and no public domain. Preserve source files needed by relative bind
mounts and review the generated deployment paths. Do not inject secrets into image
build arguments. Keep authentication state and backups out of Git.

Set these nonsecret deployment variables to reviewed values:

| Variable | Requirement |
| --- | --- |
| MAUS_BASE_IMAGE | upstream OpenMausBot repository@sha256 digest |
| MAUS_CODEX_VERSION | exact stable x.y.z npm version |
| MAUS_CADDY_IMAGE | official Caddy repository@sha256 digest |
| MAUS_SQUID_IMAGE | Ubuntu Squid 6 or 7 repository@sha256 digest |

Missing variables fail Compose expansion. Verify proxy references use digests;
variable expansion alone does not validate them. Confirm binary paths and parse
each proxy configuration using the selected images. Do not use floating tags in
saved deployment variables. Registry pulls and builds are not bounded by runtime
memory/CPU limits; schedule and monitor them separately.

## Browser access

Docker can leave a published port inactive when the container belongs only to an
internal network. No host port is now declared. Forward directly to Caddy through
SSH from the client machine:

```sh
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:18080:172.30.50.3:8080 USER@SSH_HOST
```

Then open http://localhost:18080. The host address and user are operator-specific.
Caddy requires the localhost Host and the loopback/internal gateway source for
this route. It overwrites forwarding headers and preserves browser pairing.
Do not connect the shared Coolify proxy to any of these networks.

### Optional Cloudflare Access ingress

Deploy `compose.maus-tunnel.yaml` as a **separate** Coolify application, from the
same branch, Raw Compose, manual deployment, isolated network only, no Coolify
domain. The same version-specific key-only management label is required.
The connector joins only `maus-tunnel` at 172.30.52.2. It shares no application
network or writable state with agents, and publishes no ports.

Before starting the connector:

1. Create an Access self-hosted application covering the entire chosen hostname.
   Allow only intended identities; review existing wildcard/path policies.
2. Create a dedicated remotely managed tunnel. Save only its token in the declared
   host file, mode 0400 and owner 65532:65532, inside a root-owned 0700 directory.
   Mount this file only into cloudflared. Never commit or print the token.
3. Provision `maus-tunnel`, bridge `br-maus-tunnel`, subnet 172.30.52.0/24,
   IPv6 disabled, after checking overlaps. Apply and persist firewall rules first.
   Allow the connector only to the web address/port; permit replies but reject new
   connections from agents. Allow provider DNS, Cloudflare global tunnel endpoints
   on TCP 7844, and Access certificate endpoints on TCP 443. Deny all other
   connector traffic and new connections from that bridge to the host. Cross-bridge
   exceptions must precede general isolation drops. Recheck the provider's endpoint
   list on updates; these rules do not implement general Internet access.
4. Set `MAUS_CLOUDFLARED_IMAGE` to the reviewed cloudflare/cloudflared digest in
   the connector application. Confirm selected image UID and support for
   `--token-file` (2025.4.0 or newer). HTTP/2 and IPv4 are selected explicitly;
   diagnostics listen only on connector loopback. Keep default info logging,
   never debug logging with live credentials.
5. In the **Maus application**, set `MAUS_HTTPS_HOST` to the hostname only and
   `MAUS_PUBLIC_URL` to its full HTTPS origin. Validate Caddy in a disposable
   container before deploying. Without the hostname, the public route is inactive.
6. In the tunnel, map the same hostname to `http://172.30.50.3:8080`, with
   **Protect with Access** enabled for the matching Access application/audience.
   Preserve Host and CF-Connecting-IP. This validation requires HTTPS to the
   team's cloudflareaccess.com certificate endpoint. An Access screen at the edge
   alone does not replace origin token validation.
7. Validate the connector's labels, only-network membership, resource use and
   outbound restrictions. Test an unauthenticated external browser, authorized
   login and fresh Maus pairing on the HTTPS origin. Verify Secure cookies,
   SSE streaming, wrong-host rejection, blocked hooks, and retained SSH access.
   Keep routes unpublished until configuration gates pass.

Caddy accepts the HTTPS host only from the declared connector address and sets
X-Forwarded-Proto to https on that route. It accepts the Cloudflare client address
header only there. Cloudflared must validate Access JWTs; Caddy's IP/Host matcher
does not perform that validation. The connector can carry requests to the web UI,
not read agent data or tokens from disk. The user still pairs each browser with
Maus. Access sessions and Maus sessions are independent.

Cloudflare terminates browser TLS and processes the proxied traffic. This does
not provide end-to-end secrecy from Cloudflare. Host administrators, the Docker
daemon and the shared kernel remain trusted. Runtime resource ceilings do not
limit build/pull disk usage.

To disable external access, stop the connector or remove its tunnel route, clear
the two public-origin variables and redeploy Maus. SSH still works. Do not reset
application data or provider credentials. Preserve the manual lifecycle and
revalidate the firewall after Docker/UFW/Tailscale changes.

Official references:
- [Access and origin validation](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/self-hosted-public-app/)
- [Tunnel firewall endpoints](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/tunnel-with-firewall/)
- [Tunnel runtime parameters](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/run-parameters/)

## Acceptance checks

1. Validate the rendered Compose with all reviewed variables and inspect users,
   networks, mounts, port bindings, resource limits and bounded logs.
2. Run Squid `-k parse` and Caddy `validate` in disposable containers without
   credentials. Verify source config mounts are files, not directories.
3. Verify storage capacity, permissions, mount presence, free client tunnel port,
   external network configuration and effective firewall order.
4. Start manually. Check actual container configuration and verify direct host,
   application network, metadata, public host address and internet access fail
   from the agent namespace. Test IPv6 and routing via the proxy as well.
5. Through Squid, authorized CONNECT must succeed; unknown domains, IP literals,
   private destinations, HTTP and unauthorized ports must fail. Test from the
   declared agent address because the client ACL intentionally rejects others.
6. Verify UI access through SSH and failure of direct external origin access. The local
   administrative endpoint still trusts host administrators and local processes.
7. Test Codex device login and a bounded real prompt. Never print or commit login
   credentials. Review missing exact domains individually, without broad wildcards.
   Environment-proxy support and streaming must be checked for the selected CLI.
8. Verify persistence across a manual restart and failure to write market-data
   files. Begin with a dated sample snapshot, no schedules, and one turn at a time.

Only Codex is included initially. A second provider requires a separately reviewed
CLI, destination allowlist and authentication; ChatGPT does not supply that access.
Different OpenAI roles/models do not constitute different providers.

## Verification and updates

Local preparation checked YAML parsing and key isolation invariants. No container
runtime is available in the preparation environment. Image parser tests, full
Compose validation and end-to-end behavior remain pending. Operator checks have confirmed basic SSH access and login, but no automated
server workflow or Cloudflare end-to-end verification is claimed here. Follow the upstream
`docs/verification/README.md` fixture process for subsequent server changes.

Merge upstream updates while retaining this separate deployment directory. Review
runtime image and CLI versions independently, back up state before upgrades, and
verify compatibility. Git rollback alone cannot undo state migrations. Preserve
upstream licensing notices.
