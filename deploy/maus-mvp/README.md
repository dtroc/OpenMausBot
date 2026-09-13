# Maus MVP deployment

This fork adds a restricted deployment around upstream OpenMausBot. It does not
introduce a second application engine or a financial calculation engine.
The original upstream Compose remains unchanged.

## Components and source of truth

- `compose.maus-mvp.yaml`: application, Caddy web ingress and Squid egress.
- `compose.maus-tunnel.yaml`: optional independent Cloudflare connector.
- `deploy/maus-mvp/`: build files and proxy configuration.
- `ARCHITECTURE.md`: overview; `DIARIO.md`: development history.

The application image extends a reviewed upstream image with an exact Codex CLI
version. It does not rebuild the application from this fork's TypeScript source.
Updating fork source and updating the pinned runtime image are separate operations.

Caddy's derived image removes the executable file capability that conflicts with
the restricted runtime. Validate the derived image rather than the upstream base.
Squid permits only the destinations declared in its configuration. It does not
decrypt TLS, and agents can send supplied data to an authorized provider.

## Preparation

Review the actual Compose definitions before deployment. Provision their external
networks and bind sources, checking for conflicts with existing services. Enforce
and verify host and forwarding isolation before supplying credentials. A Docker
network alone does not protect the host.

Prepare persistent state on a size-limited filesystem. Verify it is mounted before
each deployment and use the UID/GID from the selected application image. Keep
market data read-only to agents. Missing bind sources must fail, not silently
create ordinary directories outside the intended filesystem.

Use reviewed image digests for the application and proxies, and an exact Codex
version. Supply the variable names required by each Compose file through the
deployment application's environment settings. Do not inject credentials into
build arguments, commit them, or print them during diagnostics.

Resource limits apply to running containers, not registry pulls or image builds.
Containers share the host kernel and are not a virtual-machine security boundary.

## Coolify

Use the review branch and the appropriate Compose file from the repository root.
Deploy the connector as a separate application. Use Raw Compose, manual deployment
and isolated networking. Preserve repository files needed by relative bind mounts.
Do not configure a public Coolify domain for these resources.

The key-only management labels in Compose are intentional compatibility settings.
Keep their list representation and verify the effective labels and network
memberships after deployment. This behavior is version-specific, not a general
Coolify isolation guarantee. Revalidate it after platform upgrades. Do not attach
the shared proxy to these resources' dedicated networks.

Keep the manual restart policy. Stop this stack before host networking or Docker
maintenance, reapply and verify isolation, then start it manually. Ordering a
firewall service after Docker does not create an atomic startup guarantee.

## Browser access and optional Cloudflare ingress

For private access, forward a local browser port through SSH to the web service.
Use the address and listener declared in the deployment configuration. Preserve
the expected localhost Host header and complete Maus browser pairing.

For Cloudflare:
1. Create an Access application covering the entire chosen hostname and allowing
   only the intended identities. Review overlapping wildcard and path policies.
2. Create a dedicated tunnel. Store its token in a protected host file mounted
   read-only only into the connector, as declared in its Compose definition.
3. Provision and verify the connector's restricted network before starting it.
   Permit only the required origin, DNS, tunnel and Access validation destinations.
4. Set the reviewed connector image digest and confirm that its binary supports
   the configured token-file option.
5. Set the public hostname and HTTPS origin variables in the Maus application.
   Validate Caddy using the selected image before deployment.
6. Configure the tunnel origin to the web listener. Enable **Protect with Access**
   for the matching application audience; preserve Host and CF-Connecting-IP.
7. Verify the connector's effective configuration and test Access login, fresh
   Maus pairing, secure cookies, streaming and retained SSH access.

Caddy must match the peer address it actually sees. Bridge source NAT can change
that address, so a pre-NAT container address is not necessarily a valid matcher.
An IP/Host matcher is not JWT validation: keep origin validation enabled in the
connector and preserve the network restrictions required by this deployment.

Cloudflare terminates browser TLS and processes the proxied traffic. Access and
Maus sessions are independent. Host administrators and the container runtime
remain trusted. Keep the hostname unpublished until the configuration gates pass.

To disable external access, stop the connector or remove its route, clear the
public-origin variables and redeploy Maus. Preserve application state and provider
credentials.

## Verification and updates

Validate Compose expansion and inspect effective users, mounts, networks, labels,
port bindings and resource limits. Parse proxy configuration with the pinned
images in disposable containers without credentials. Test permitted traffic and
prohibited host, cross-network and direct internet connections.

Use bounded read-only HTTP checks for ingress diagnostics. Recheck wrong-host and
webhook rejection after changes. Configuration review is not evidence that a live
Access flow works; record operator results separately from pending checks.

For application/server changes, follow `docs/verification/README.md` and use an
isolated fixture. Do not test mutations against the user's live data.
Merge upstream updates while retaining this deployment configuration, back up
state before upgrades, and review runtime versions separately. Git rollback does
not reverse data migrations. Preserve upstream license notices.

OptionData export is a subsequent step; no exporter is implemented here. Only
Codex is included initially. Another provider requires separate configuration and
authentication. Different personas do not by themselves imply different providers.

## Official references

- [Docker bridge networking](https://docs.docker.com/engine/network/drivers/bridge/)
- [Caddy request matchers](https://caddyserver.com/docs/caddyfile/matchers)
- [Access and origin validation](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/self-hosted-public-app/)
- [Tunnel firewall endpoints](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/tunnel-with-firewall/)
- [Tunnel runtime parameters](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/run-parameters/)
