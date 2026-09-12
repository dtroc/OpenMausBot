# Diario del fork

## 2026-09-12 — Preparación de Maus MVP en Coolify

- Añadido `compose.maus-mvp.yaml` sin modificar el Compose original.
- Separados servidor, proxy web local y proxy de salida Squid con dominios exactos.
- Añadidos permisos mínimos, límites de recursos, bind de datos de mercado de solo
  lectura, logs acotados y despliegue manual sin reinicio automático.
- Versiones de imágenes y Codex obligatorias, pendientes de resolver en el VPS.
- Documentados arquitectura, almacenamiento con cuota, preparación del host,
  limitaciones del firewall al reiniciar/recargar y pruebas de aceptación.
- Validación estática local; despliegue, parsers de imágenes y autenticación real
  pendientes. No se ha ejecutado ningún agente ni accedido a datos del usuario.
