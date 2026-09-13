# Resumen de configuración de OpenMausBot MVP

Documento público · 13 de septiembre de 2026

## 1. Objetivo y alcance

Este despliegue permite probar conversaciones entre agentes y preparar propuestas
de inversión y operaciones simuladas. La primera fase puede trabajar con datos
pegados manualmente o con snapshots. No incluye ejecución de órdenes reales,
conexión automática con un bróker ni un sistema completo de auditoría financiera.

El documento explica las decisiones y el procedimiento de mantenimiento de forma
general. Omite credenciales, identidades, dominios de uso, direcciones del servidor,
inventario de otras aplicaciones, identificadores de recursos y salidas operativas.
Los valores de una instalación deben mantenerse en un registro privado.

## 2. Componentes

| Componente | Función | Configuración en el repositorio |
| --- | --- | --- |
| OpenMausBot | Interfaz, conversaciones, personas y coordinación de motores | `compose.maus-mvp.yaml` |
| Extensión de imagen | Instala una versión explícita de Codex CLI sobre una imagen base fijada | `deploy/maus-mvp/Dockerfile` |
| Caddy | Recibe tráfico web y lo entrega al servidor de Maus | `deploy/maus-mvp/Caddyfile` |
| Imagen derivada de Caddy | Adapta el ejecutable a una ejecución con capacidades reducidas | `deploy/maus-mvp/Caddy.Dockerfile` |
| Squid | Controla las conexiones salientes mediante un proxy explícito | `deploy/maus-mvp/squid.conf` |
| Cloudflared | Conecta el acceso publicado con el servicio web | `compose.maus-tunnel.yaml` |
| Cloudflare Access | Aplica autenticación y políticas de acceso | Configuración externa al repositorio |
| Coolify | Obtiene los archivos del repositorio y ejecuta los despliegues manuales | Configuración externa al repositorio |

Los dos Compose son recursos independientes: uno contiene Maus y sus proxies;
el otro contiene el conector. El Compose original de upstream se conserva.

La imagen de Maus se deriva de una imagen upstream. Cambiar el código TypeScript
del fork no reconstruye automáticamente la aplicación incluida en esa imagen.
La actualización del repositorio y la de la imagen de ejecución son operaciones
distintas y deben revisarse por separado.

## 3. Acceso al servicio

Hay dos métodos previstos: acceso privado mediante túnel SSH y acceso mediante
un dominio protegido por Cloudflare Access. El navegador completa además la
vinculación propia de Maus. Estas sesiones son independientes.

### Acceso privado

El túnel SSH conecta un puerto local del equipo del operador con el listener web.
La configuración distingue las peticiones de localhost del acceso publicado.
El puerto local y el destino se eligen conforme al despliegue; este documento no
incluye comandos con direcciones reales.

### Acceso publicado

La aplicación de Access debe cubrir el hostname completo y permitir únicamente
las identidades previstas. Debe existir antes de publicar la ruta del túnel.
El conector utiliza la opción de validación JWT de Access y la audiencia de la
aplicación correspondiente. Mostrar una pantalla de login no sustituye esa
validación en el origen.

Caddy conserva la distinción entre HTTP privado y HTTPS publicado mediante las
cabeceras de proxy previstas. Debe mantener la coherencia entre hostname, origen
público y protocolo para que funcionen correctamente las sesiones del navegador.
La configuración bloquea la entrada de webhooks y rechaza rutas de acceso que
no coinciden con los criterios establecidos.

La traducción de direcciones entre redes puede cambiar la dirección del cliente
que observa Caddy. Por ello, su matcher debe reflejar el origen posterior a NAT;
la restricción del origen original corresponde al firewall. Un matcher de IP y
hostname no constituye por sí solo una identidad autenticada.

### Vinculación de navegadores

El código de vinculación se obtiene mediante la CLI de Maus y se introduce en el
navegador que se quiere autorizar. Es temporal y de un solo uso. Debe tratarse
como una credencial y no publicarse ni incorporarse a logs compartidos.

Cada navegador y dispositivo tiene su sesión. El cambio de localhost a un dominio
crea un contexto de navegador diferente. Borrar cookies, usar navegación privada,
revocar una sesión o su caducidad puede requerir una nueva vinculación. El móvil
puede usar un código generado desde otro equipo autorizado; no necesita ejecutar
la CLI localmente.

## 4. Restricciones de ejecución

Los servicios usan usuarios sin privilegios, sistema raíz de solo lectura,
eliminación de capacidades Linux y `no-new-privileges`. Los directorios temporales
se ofrecen mediante `tmpfs` con tamaños limitados y opciones restrictivas cuando
son compatibles con el programa. No todos los temporales pueden marcarse como
no ejecutables sin comprobar el comportamiento de los motores.

Se acotan memoria, swap del contenedor, CPU, procesos y logs. Los límites concretos
están en los Compose. Estos límites reducen el impacto sobre el servidor, pero no
reservan recursos ni limitan por sí mismos el consumo de las construcciones de
imágenes, las descargas o la suma de todas las aplicaciones del host.

No se monta el socket de Docker, no se utiliza la red del host y no se entregan
al agente las claves SSH ni el token de despliegue del conector.

Los contenedores comparten el kernel del host. Este diseño reduce superficie de
acceso, pero no equivale al aislamiento de una máquina virtual ni elimina todos
los riesgos de ejecutar agentes sobre infraestructura compartida.

## 5. Redes y salida controlada

La aplicación, el proxy de salida y el conector tienen funciones de red distintas.
El agente utiliza una red interna. El proxy proporciona la salida permitida y
el conector mantiene su propia red. La topología exacta está declarada en Compose;
las redes externas deben existir antes del despliegue.

El firewall del host complementa esa topología. Debe restringir conexiones hacia
el host, conexiones entre redes y destinos de salida. Las excepciones para el
tráfico requerido deben ser precisas y estar antes de los bloqueos generales.
Las respuestas de conexiones permitidas requieren tratamiento de estado adecuado.

Squid limita clientes, método CONNECT, puerto TLS y destinos autorizados. Bloquea
otros destinos, incluidos los rangos internos definidos en su política. El agente
recibe variables de proxy; su presencia no demuestra que todos los programas las
respeten, por lo que se verifican también las conexiones directas.

Squid no descifra TLS. Autorizar un destino permite tráfico cifrado hacia él y
no limita automáticamente su contenido. Los datos que recibe un agente pueden
llegar al proveedor de modelos autorizado.

El conector requiere conectividad específica para el túnel, DNS y validación de
Access. Sus necesidades se revisan con la documentación del proveedor; no justifican
una salida general a Internet. IPv6 y reenvío de paquetes deben tratarse
explícitamente para evitar caminos no contemplados.

La persistencia del firewall forma parte de la preparación del host, fuera del
Compose. Una unidad ordenada después de Docker no garantiza que ninguna aplicación
arranque antes que las reglas. Tras mantenimiento de Docker, del firewall o de la
red, se reaplican y verifican las restricciones antes de iniciar manualmente el MVP.

## 6. Estado persistente y secretos

El estado de Maus se separa de los datos de mercado. El primero es escribible
por la aplicación; los snapshots de mercado se montan en modo de solo lectura.
La propiedad de los directorios debe coincidir con el usuario de la imagen.

El almacenamiento de estado utiliza un filesystem de tamaño limitado, con opciones
de montaje restrictivas. Es necesario comprobar que está montado antes de iniciar
los servicios. Un directorio ordinario no sustituye una cuota, y la existencia del
directorio por sí sola no demuestra que el volumen esperado esté montado.

Los binds se configuran para evitar crear silenciosamente fuentes inexistentes.
Debe revisarse también el comportamiento de la plataforma de despliegue, porque
un paso previo puede crear directorios antes de que Docker procese los binds.

El token del túnel se entrega como archivo protegido de solo lectura exclusivamente
al conector. El estado de autenticación del motor es sensible y puede formar parte
del almacenamiento persistente. Las copias deben conservar permisos, mantenerse
fuera de Git y protegerse durante su almacenamiento y transporte.

No hay una copia de seguridad verificada ni restauración automática implícita en
estos archivos. Debe establecerse y probarse una política de respaldo independiente.

## 7. Versiones y variables

| Variable | Tipo de configuración, sin valor operativo |
| --- | --- |
| `MAUS_BASE_IMAGE` | Imagen upstream fijada por digest |
| `MAUS_CODEX_VERSION` | Versión explícita de Codex CLI |
| `MAUS_CADDY_IMAGE` | Imagen base de Caddy fijada por digest |
| `MAUS_SQUID_IMAGE` | Imagen de Squid revisada y fijada por digest |
| `MAUS_CLOUDFLARED_IMAGE` | Imagen del conector fijada por digest |
| `MAUS_PUBLIC_URL` | Origen público completo de la instalación |
| `MAUS_HTTPS_HOST` | Hostname esperado, sin protocolo |

Los valores de las imágenes se obtienen y revisan al preparar cada instalación.
Fijar un digest estabiliza el contenido descargado; no certifica que sea seguro.
Las actualizaciones siguen requiriendo revisión de procedencia y compatibilidad.

Las variables se guardan en el recurso correspondiente de Coolify. El token del
conector no se añade al repositorio ni se convierte en argumento de construcción.

## 8. Codex, personas y datos de inversión

Codex CLI es el motor incorporado inicialmente. Su autenticación se realiza por
el flujo oficial admitido por el proveedor. Las credenciales no se sustituyen por
una clave extraída de una sesión del navegador. La disponibilidad y el consumo
dependen del método de autenticación y de las condiciones vigentes del proveedor.

Las personas representan responsabilidades e instrucciones; no garantizan que
cada una use un proveedor diferente. La selección del motor y modelo se revisa
por bot y según lo que soporte la versión de Maus utilizada. Añadir otro proveedor
requiere adaptar su instalación, autenticación y destinos permitidos.

Para la fase inicial pueden definirse roles de analista, riesgos y CIO, con una
reunión limitada y conclusiones expresamente simuladas. Los datos pegados deben
incluir fecha, unidades, contexto y limitaciones. Un snapshot no debe presentarse
como una fuente en tiempo real ni completarse con cifras inventadas.

El montaje para datos de mercado prepara un canal de lectura. No constituye una
integración automática con OptionData. La extracción, normalización, actualización,
control de duplicados y trazabilidad de esos datos son trabajos posteriores.
Tampoco se incluye un libro de operaciones simuladas validado ni auditoría formal.

## 9. Coolify y mantenimiento de ramas

Cada recurso debe apuntar al repositorio, rama y Compose correctos. La base `/`
significa la raíz del repositorio; no identifica la rama. Si el parser recibe
contenido vacío, se comprueba la rama y la ruta y se carga el Compose antes de
modificar opciones de ejecución.

La configuración emplea Raw Compose, redes aisladas y despliegue manual. Las
etiquetas de compatibilidad declaradas en los servicios son intencionadas. Su
comportamiento depende de la versión de Coolify y debe revisarse al actualizar:
no basta con suponer que Raw impide que el proxy compartido se conecte a las redes.

La fusión en GitHub no cambia automáticamente la rama elegida en Coolify:

1. Completar la revisión y fusionar los archivos en `main`.
2. Cambiar a `main` la rama de las dos aplicaciones.
3. Mantener los respectivos Compose, variables, redes y volúmenes.
4. Desplegar en una ventana adecuada y comprobar estado y acceso.
5. Eliminar la rama anterior solo cuando ninguna aplicación dependa de ella.

El despliegue puede interrumpir conversaciones activas. Cambiar una rama no mueve
ni borra por sí mismo los datos montados, pero alterar los nombres o destinos de
volúmenes puede conectar la aplicación a otro almacenamiento.

Para incorporar actualizaciones upstream, revisar diferencias y fusionarlas en
una rama de trabajo conservando la configuración propia. No sobrescribir el fork
completo. Actualizar también las imágenes cuando corresponda, con pruebas previas.

## 10. Compatibilidad y comprobaciones

Las decisiones de compatibilidad que motivan esta configuración son:

- Retirar de la imagen derivada de Caddy una capacidad de archivo incompatible
  con el límite de capacidades elegido, conservando la ejecución sin privilegios.
- Acotar descriptores de archivo de Squid para evitar reservas excesivas al arrancar.
- Comprobar las redes efectivas y las etiquetas añadidas por la plataforma.
- Usar el listener interno como destino privado cuando la publicación de puertos
  no se materializa en una red interna.
- Ajustar los matchers al efecto de NAT en las conexiones entre bridges.

La validación estática revisa YAML, referencias, restricciones y ausencia de
secretos en la documentación. Las pruebas de ejecución se realizan con las imágenes
elegidas, utilizando contenedores desechables sin credenciales cuando sea posible.

La aceptación operativa incluye arranque y salud, uso de recursos, redes efectivas,
acceso permitido, bloqueos de salida, acceso privado y autenticación por el dominio
publicado. Deben comprobarse además persistencia, rechazo de hosts no previstos,
validación JWT, sesiones y streaming. Un HTTP 200 solo confirma esa petición;
no certifica el conjunto del aislamiento ni todos los flujos de la aplicación.

El operador ha comunicado que el acceso funcional del MVP funciona. Ese resultado
no equivale a una auditoría independiente, una prueba de restauración o una
validación exhaustiva después de reinicios. Este documento no publica evidencias
privadas ni afirma haber ejecutado una batería automatizada completa.

## 11. Recuperación y próximos pasos

Para retirar el acceso publicado, detener el conector o retirar su ruta. Para
volver al acceso privado, ajustar las variables públicas y comprobar el túnel SSH.
No borrar el estado para solucionar un problema de autenticación o de red.

Antes de volver a una versión anterior, comprobar compatibilidad de datos y copias.
Revertir Git o un digest no deshace migraciones que ya hayan modificado el estado.
Tras reinicios del host, verificar almacenamiento y firewall antes de arrancar.

Quedan fuera de esta fase la automatización de OptionData, un historial de
decisiones auditable, la contabilidad de paper trades, la ejecución real y las
actualizaciones automáticas. Cada ampliación debe justificar permisos y datos
adicionales, incorporar pruebas apropiadas y actualizar este resumen.

## 12. Referencias dentro del repositorio

- [Guía de despliegue](../deploy/maus-mvp/README.md).
- [Arquitectura del fork](../ARCHITECTURE.md).
- [Diario de desarrollo](../DIARIO.md).
- [Procedimiento de verificación de la aplicación](verification/README.md).

La guía de despliegue enlaza las referencias oficiales de Docker, Caddy y
Cloudflare. Los cambios del servidor o de conversaciones deben seguir el
procedimiento de fixtures aislados del proyecto, sin mutar datos reales para probar.
