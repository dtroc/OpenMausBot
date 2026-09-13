ARG BASE_IMAGE
FROM ${BASE_IMAGE}
USER root
ARG BASE_IMAGE
ARG CODEX_VERSION
# Reject floating references and shell/package arguments outside an exact version.
RUN printf '%s' "$BASE_IMAGE" | grep -Eq '^ghcr\.io/milind-soni/openmausbot@sha256:[0-9a-f]{64}$' \
 && printf '%s' "$CODEX_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' \
 && npm install -g --no-audit --no-fund "@openai/codex@${CODEX_VERSION}" \
 && npm cache clean --force \
 && test "$(id -u maus)" -ne 0
USER maus
