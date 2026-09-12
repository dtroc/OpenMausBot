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

### Corrección de ejecución de Caddy

- Confirmada la capacidad de archivo `cap_net_bind_service=ep` en la imagen
  oficial seleccionada, incompatible con la ejecución restringida prevista.
- Añadido `Caddy.Dockerfile` para quitar esa capacidad durante la construcción;
  el servicio web usa la imagen derivada y mantiene usuario sin privilegios,
  `cap_drop: ALL` y `no-new-privileges`.
- La validación de ejecución y configuración de la imagen derivada sigue pendiente.

### Límite de descriptores para Squid

- Acotados a 1024 los descriptores de archivo en Docker y en Squid para evitar
  reservas de memoria de arranque asociadas a límites heredados excesivos.
- Se mantienen los 128 MiB de memoria y todas las restricciones de seguridad.
- YAML validado; pendiente comprobar el arranque y consumo real del proxy corregido.
- La configuración de Caddy derivado ha pasado la validación con ejecución restringida.
