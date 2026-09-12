# Diario del fork

## 2026-09-12 — Archivos de despliegue del MVP

- Añadido `compose.maus-mvp.yaml` como alternativa al Compose upstream.
- Añadidos archivos de construcción y configuración en `deploy/maus-mvp/`.
- Ajustada la construcción de Caddy para compatibilidad con permisos reducidos.
- Acotado el número de descriptores de archivo en el servicio de salida.
- Añadidas etiquetas de compatibilidad para el despliegue mediante Compose.
- Añadido `compose.maus-tunnel.yaml` como recurso opcional separado.
- Parametrizadas las variables de origen público.
- Corregido el matcher de Caddy para contemplar NAT entre redes.
- Generalizada la guía pública y conservadas referencias a la documentación oficial.

### Alcance de la verificación

La revisión de estos archivos es estática. El operador debe validar las
configuraciones con las imágenes seleccionadas y completar las comprobaciones
funcionales descritas en la guía. Este diario no registra inventario del host,
credenciales ni estado de autenticación de usuarios.
