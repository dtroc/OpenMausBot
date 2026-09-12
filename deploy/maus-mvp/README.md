# Maus MVP deployment

Status: configuration prepared, not deployed. Runtime parsers, Codex authentication,
storage preparation and full acceptance checks remain pending. This document
intentionally contains no inventory or observed configuration of the operator host.

## Components

`compose.maus-mvp.yaml` is a separate deployment definition; the upstream Compose
is unchanged. `omb` extends a pinned upstream image with an exact Codex CLI version.
It does not rebuild the application from this fork's TypeScript source. Updating
the fork and updating the runtime image are separate operations.

Caddy provides an SSH-only localhost UI while preserving the harness loopback
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

## Acceptance checks

1. Validate the rendered Compose with all reviewed variables and inspect users,
   networks, mounts, port bindings, resource limits and bounded logs.
2. Run Squid `-k parse` and Caddy `validate` in disposable containers without
   credentials. Verify source config mounts are files, not directories.
3. Verify storage capacity, permissions, mount presence, free localhost port,
   external network configuration and effective firewall order.
4. Start manually. Check actual container configuration and verify direct host,
   application network, metadata, public host address and internet access fail
   from the agent namespace. Test IPv6 and routing via the proxy as well.
5. Through Squid, authorized CONNECT must succeed; unknown domains, IP literals,
   private destinations, HTTP and unauthorized ports must fail. Test from the
   declared agent address because the client ACL intentionally rejects others.
6. Verify UI access through SSH and failure from external machines. The local
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
Compose validation and end-to-end behavior remain pending. No server workflow,
authentication or first meeting is claimed to work yet. Follow the upstream
`docs/verification/README.md` fixture process for subsequent server changes.

Merge upstream updates while retaining this separate deployment directory. Review
runtime image and CLI versions independently, back up state before upgrades, and
verify compatibility. Git rollback alone cannot undo state migrations. Preserve
upstream licensing notices.
