# Módulo 3 · Actores, servicios y gobernanza

Autor responsable **Leonardo Enrique Chacón Agraz** (C.I. 31.895.402).

## Arranque local

1. Copia `.env.example` a `.env`. Conserva la configuración de PostgreSQL del proyecto y añade `M3_DB_PASSWORD`, `M3_REPORTS_PASSWORD` y `M3_SESSION_SECRET` con valores propios. Puedes generar cada valor con `python -c "import secrets; print(secrets.token_urlsafe(32))"`. La contraseña de reportes se usa para el acceso JDBC y el secreto firma las sesiones web.
2. Para habilitar el perfil administrativo en la demostración, añade `M3_ADMIN_RIF=G-99000004-0` en `.env`. El RIF corresponde a un ente público ficticio. Úsalo solo con la base de datos de prueba. Una instalación con datos reales debe provisionar su propio ente y excluir la carga de demostración.
3. Desde la raíz, ejecuta `docker compose up -d` con un volumen nuevo. PostgreSQL ejecuta el directorio `database` en el orden acordado. Si el proyecto ya tiene un volumen, la inicialización automática se ejecutó en su primera creación. Usa una base de prueba nueva para instalar estos scripts.
4. Desde la raíz, inicia la aplicación web.

   ```powershell
   python -m venv .venv
   .venv/Scripts/python -m pip install -r backend/requirements.txt
   .venv/Scripts/python -m uvicorn --app-dir backend app.main:app --reload
   ```

   En macOS o Linux sustituye `.venv/Scripts/python` por `.venv/bin/python`. Abre [el módulo 3](http://127.0.0.1:8000/modulo-3/) o [la documentación interactiva de la API](http://127.0.0.1:8000/docs).

### Perfiles de demostración

Las cuentas son ficticias y comparten la contraseña de prueba `RutasDemo2026!`.

| Perfil de acceso | Identificador | Complemento |
|---|---|---|
| Visitante | `V-90000001` | Cédula |
| Guía turístico | `RTN-DEMO-1` | `LIC-DEMO-1` |
| Comercio aliado | `J-99000001-0` | |
| Ente público | `G-99000001-0` | Bandeja de Caracas |
| Administración | `G-99000004-0` | Inicia sesión como Ente público con `M3_ADMIN_RIF` configurado |

La credencial `M3DEMO011` permite probar la autenticidad y consultar su validador. Su fecha programada se calcula durante la carga. El botón de canje se habilita para el validador asignado en el día de visita y dentro del intervalo operativo. Para demostrar el flujo institucional, un visitante crea el reporte y el ente que tiene tutela sobre el hito lo confirma desde su bandeja.

## Dependencias e integración

- El ZIP inicial trae el DDL de Hito y las categorías del modelo corregido. La carga de M3 agrega seis hitos de demostración si M1 todavía no ha cargado su catálogo.
- El archivo `04_m2_infraestructura_rutas.sql` va antes de `05_m3_transacciones_gobernanza.sql`. Los datos de M2 van entre `02_m3_actores_seeds.sql` y `04_m3_transacciones_seeds.sql`. La base se puede inicializar antes de integrar M2. Las experiencias y adscripciones se habilitan al ejecutar los scripts en una base nueva que incluya el DDL de Ruta. El historial de M2 permite verificar reseñas de rutas y visitas registradas como pasos. Para verificar reseñas de hitos, M3 también admite credenciales canjeadas.
- Las categorías unión y especializaciones se validan al confirmar la transacción. Crea la categoría y su miembro dentro de la misma transacción. Al eliminar el último miembro de una categoría, elimina también su fila de categoría en esa transacción si no hay referencias. Los cambios en el perfil de un actor y sus relaciones se guardan juntos.
- FastAPI conecta con `svc_rutas_web`, consulta el perfil de acceso y usa el rol PostgreSQL correspondiente dentro de cada transacción. Jasper usa la cuenta de solo lectura `svc_rutas_reportes`. Las credenciales de conexión pertenecen al servidor. Los visitantes, guías, comercios y entes ingresan con su identificador del dominio.
- El backend compartido de `dev` carga los routers de autenticación y M3. La interfaz de M3 se sirve en `/modulo-3/` y la API sigue el contrato de paginación del equipo bajo `/api/m3`.

## Reglas operativas

- Una experiencia exige comercio promotor, guía director, ruta y al menos un detalle. La consulta de promociones conserva las claves territoriales de la ruta y considera ambos extremos de la vigencia.
- El canje usa la hora de Caracas. Se admite el mismo día de visita, hasta la hora reservada, con el servicio operativo y dentro de su horario. Los hitos de libre acceso quedan fuera de la boletería. El monto registra un abono declarado en la prueba académica. El proyecto no incluye una pasarela de pagos.
- Las incidencias de visitantes y guías nacen preliminares. Para hitos con tutela, la bandeja y la confirmación aplican esa asignación. Para hitos sin tutela y tramos, la bandeja admite revisión institucional, pues el modelo no vincula la jurisdicción del ente al tramo. El ente que confirma queda a cargo de las prórrogas y del cierre. Una alerta confirmada cuyo plazo expiró aparece como **Fuera de plazo** hasta que se prorrogue o cierre. El estado almacenado conserva la confirmación y las prórrogas forman un historial.

## Reporte 3 · Observatorio de severidad

La sección **Observatorio** permite filtrar y descargar el resultado en CSV. La plantilla [JasperReports](../reports/03_m3_observatorio_incidencias.jrxml) se conecta a la misma vista de PostgreSQL. En Jaspersoft Studio con JasperReports 6.21.3, crea un adaptador JDBC de PostgreSQL con `jdbc:postgresql://localhost:5432/rutas_venezuela_db` y la cuenta de informes. Ajusta el puerto y la base a tu `.env` y abre **Preview**. Los filtros `ESTADO`, `SEVERIDAD`, `TIPO_ELEMENTO`, `DESDE` y `HASTA` son opcionales. Usa los valores almacenados, por ejemplo `Critico` en severidad. El reporte muestra el porcentaje de críticas sobre el conjunto filtrado y los tiempos promedio en horas.

## Archivos para la rama de M3

- El esquema, las vistas y su limpieza están en `database/01_ddl/00_m3_limpieza.sql`, `03_m3_actores.sql`, `05_m3_transacciones_gobernanza.sql` y `08_m3_vistas_indices.sql`. Los roles y permisos están en `database/02_security`, las reglas en `database/03_logic/03_m3_plpgsql.sql` y los datos en `database/04_seeds`.
- Los routers y la conexión por rol de M3 están en `backend`. La interfaz está en `frontend/modulo-3/index.html`, `frontend/css/m3.css` y `frontend/js/modules/m3_transacciones.js`. El JRXML se encuentra en `reports`.
