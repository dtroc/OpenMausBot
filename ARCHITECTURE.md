# Architecture of this deployment fork

The upstream OpenMausBot application is documented in [README.md](README.md) and
its `docs/` directory. This fork initially adds deployment configuration, not a
second application engine or a financial calculation engine.

The shared-VPS MVP architecture, trust boundaries, files, lifecycle, storage and
acceptance gates are maintained in one place:
[deploy/maus-mvp/README.md](deploy/maus-mvp/README.md).

Entry point: `compose.maus-mvp.yaml`. The original `compose.yaml` remains the
upstream deployment. Updating fork source and updating the pinned runtime image
are separate operations. No new application API is introduced by this change.

Optional ingress: `compose.maus-tunnel.yaml` runs a dedicated Cloudflare connector
in its own network. Host firewall permits only web ingress and required Cloudflare
egress. Access JWT validation at the connector precedes Maus browser pairing.
See the deployment README for configuration and acceptance requirements.

Public configuration and operations summary (Spanish):
[docs/CONFIGURACION_MVP.md](docs/CONFIGURACION_MVP.md).
