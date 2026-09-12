ARG BASE_IMAGE
FROM ${BASE_IMAGE}
USER root
ARG BASE_IMAGE
# Upstream grants file capabilities for low ports. We use 8080 and drop ALL
# runtime capabilities; keeping that file capability causes execve EPERM.
RUN printf '%s' "$BASE_IMAGE" | grep -Eq '^caddy@sha256:[0-9a-f]{64}$' \
 && setcap -r /usr/bin/caddy \
 && test -z "$(getcap /usr/bin/caddy)"
USER 65534:65534
