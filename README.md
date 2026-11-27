# Rutas Venezuela — Plataforma de Rutas Turísticas y Culturales

Repositorio oficial del proyecto para la **Segunda Entrega de Bases de Datos**. Contiene el esquema relacional, seguridad lógica, funciones/triggers en PL/pgSQL, datos de prueba y la aplicación web del sistema **Rutas Venezuela**.

---

## ¿Cómo funciona este entorno y por qué evita errores entre computadoras?

Para evitar el problema de _"en mi máquina sí funciona y en la de mis compañeros no"_, este proyecto no depende de instalaciones manuales de PostgreSQL en Windows, macOS o Linux. En su lugar, utiliza **Docker Compose** para levantar un contenedor aislado y exactamente igual para todos:

1. **Motor idéntico (`docker-compose.yml`):** Descarga automáticamente la imagen oficial `postgres:16.4-alpine` configurada con zona horaria `America/Caracas` y codificación `UTF-8`.
2. **Credenciales unificadas (`.env`):** Todos los integrantes usan el mismo usuario, contraseña, puerto y nombre de base de datos a partir de `.env.example`, evitando fallos de conexión en el backend o en pgAdmin.
3. **Automatización de scripts (`database/` + `00_init.sh`):** Cada vez que la base de datos se crea desde cero, el script [`database/00_init.sh`](./database/00_init.sh) recorre las subcarpetas de `database/` y ejecuta automáticamente todos los archivos `.sql` en estricto orden alfabético por carpeta:
   - `01_ddl/` → Creación y modificación de tablas (`DROP`, `CREATE`, `ALTER`), vistas e índices usando tipos de datos primitivos estándar (sin extensiones espaciales).
   - `02_security/` → Roles, cuentas de usuario y permisos (`GRANT` / `REVOKE`).
   - `03_logic/` → Reglas de integridad automatizadas: triggers, funciones y procedimientos almacenados en PL/pgSQL.
   - `04_seeds/` → Carga inicial (`INSERT`) de datos realistas del contexto turístico venezolano.
4. **Persistencia local (`postgres_data`):** Los datos que registres mientras pruebas se guardan en un volumen local de Docker en tu máquina, y puedes reiniciarlos a un estado limpio en segundos cuando un compañero suba cambios nuevos.

---

## 1. Descarga e Instalación de Herramientas (Solo la primera vez)

> **Importante:** No instales PostgreSQL de forma nativa en tu sistema operativo. Si ya lo tienes instalado, detén el servicio antes de continuar para que no ocupe el puerto `5432`.

1. **Git:** Descárgalo desde [git-scm.com](https://git-scm.com/) e instálalo con las opciones por defecto.
   - _Verificación:_ Ejecuta `git --version` en la terminal; debe mostrar la versión instalada.
2. **Docker Desktop:**
   - Descárgalo desde [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/).
   - En Windows, deja marcada la opción **Use WSL 2 instead of Hyper-V** y reinicia tu computadora al terminar.
   - Abre **Docker Desktop** y espera a que en la esquina inferior izquierda aparezca el indicador verde **Engine running**.
   - _Verificación:_ Ejecuta `docker compose version` en la terminal.
3. **pgAdmin 4 (Cliente visual):**
   - Descárgalo desde [pgadmin.org/download](https://www.pgadmin.org/download/) (solo pgAdmin 4, sin el servidor de PostgreSQL).
   - Al abrirlo por primera vez, define una **contraseña maestra** (_Master Password_) local para proteger tus conexiones guardadas.

---

## 2. Configuración del Proyecto y Arranque de PostgreSQL

Abre **Git Bash** (o la terminal de VS Code) y ejecuta estos pasos en orden:

1. **Configura tu identidad en Git** (obligatorio para dejar registro de autoría en cada commit):

   ```bash
   git config --global user.name "Tu Nombre y Apellido"
   git config --global user.email "tu_correo@ejemplo.com"
   ```

2. **Clona el repositorio y cámbiate a la rama de desarrollo (`dev`):**

   ```bash
   git clone <URL_DEL_REPOSITORIO>
   cd rutas-venezuela
   git checkout dev
   ```

3. **Crea tu archivo local de variables de entorno (`.env`):**

   ```bash
   cp .env.example .env
   ```

4. **Descarga y enciende el contenedor de PostgreSQL:**
   ```bash
   docker compose up -d
   ```
   _(La primera vez tardará ~1 minuto mientras descarga PostgreSQL 16.4 y ejecuta los scripts de `database/`)._
   - _Verificación:_ Ejecuta `docker compose ps` y confirma que el estado (`STATUS`) dice `Up`.

---

## 3. Conexión en pgAdmin 4

Con el contenedor encendido (`Up`), registra el servidor en **pgAdmin 4**:

1. En el panel izquierdo (_Object Explorer_), haz clic derecho sobre **Servers** > **Register** > **Server...**
2. En la pestaña **General**, coloca:
   - **Name:** `Rutas Venezuela (Local)`
3. En la pestaña **Connection**, ingresa exactamente estos valores:
   - **Host name/address:** `localhost`
   - **Port:** `5432`
   - **Maintenance database:** `rutas_venezuela_db`
   - **Username:** `admin_rutas`
   - **Password:** `rutas_dev_password_2026`
   - Activa la casilla **Save password?**.
4. Haz clic en **Save**. Podrás explorar las tablas en `Rutas Venezuela (Local)` > `Databases` > `rutas_venezuela_db` > `Schemas` > `public` > `Tables`.

---

## 4. Cómo Crear Tablas, Triggers y Datos (pgAdmin vs. Repositorio)

> **Regla crítica:** **pgAdmin NO guarda archivos en tu carpeta ni hace `push` automático a GitHub.** Si creas tablas usando los clics visuales de pgAdmin y no guardas el código `.sql` en el repositorio, tus compañeros no recibirán tus cambios y se borrarán al reiniciar Docker.

Para que todo quede versionado y cumpla con la entrega de scripts con autoría, sigue siempre este ciclo de 4 pasos:

1. **Prueba tu SQL en pgAdmin:**
   - Haz clic derecho sobre `rutas_venezuela_db` > **Query Tool**.
   - Escribe y ejecuta ahí tus sentencias (`CREATE TABLE`, `ALTER TABLE`, `CREATE TRIGGER`, `INSERT`, etc.) para validar que no tengan errores.
   - _(Tip: Si creaste una tabla usando los menús visuales de pgAdmin, haz clic derecho sobre la tabla > **Scripts** > **CREATE Script** para obtener el código SQL generado)._
2. **Guarda el código `.sql` en tu carpeta clonada:**
   - Abre el proyecto en VS Code y pega el código SQL probado dentro de la carpeta correspondiente (`database/01_ddl/`, `02_security/`, `03_logic/` o `04_seeds/`).
   - Añade un comentario al inicio del archivo indicando tu **nombre completo** para registrar tu autoría.
3. **Verifica que el proyecto levanta limpio desde cero:**
   - Ejecuta `docker compose down -v && docker compose up -d` en tu terminal y haz **Refresh** sobre `rutas_venezuela_db` en pgAdmin. Si tus tablas y datos aparecen automáticamente, el script está listo.
4. **Sube tus archivos `.sql` a GitHub:**
   - Haz `git add .`, `git commit -m "feat: descripción de tus tablas/scripts"` y `git push` en tu rama de trabajo, y abre un _Pull Request_ hacia `dev`.

---

## 5. Flujo de Trabajo Diario y Reglas del Equipo

### A. Cómo actualizar tu base de datos cuando un compañero sube cambios

Cada vez que descargues cambios nuevos desde GitHub (`git pull origin dev`) que modifiquen tablas, triggers, roles o datos de prueba, reconstruye tu base de datos limpia ejecutando:

```bash
docker compose down -v && docker compose up -d
```

- El parámetro `-v` elimina el volumen local anterior y vuelve a ejecutar en orden todas las carpetas de `database/`.
- Luego, en **pgAdmin 4**, haz clic derecho sobre `rutas_venezuela_db` y selecciona **Refresh**.

### B. Convenciones obligatorias para la Segunda Entrega

- **Prefijos numéricos:** Todo archivo nuevo dentro de `01_ddl/`, `02_security/`, `03_logic/` o `04_seeds/` debe comenzar con un número de dos dígitos para controlar su orden de ejecución (ejemplo: `01_territorio.sql`, `02_hitos.sql`).
- **Autoría explícita:** Todo archivo `.sql`, tabla, trigger o función en PL/pgSQL debe incluir un comentario en su encabezado con el nombre completo del integrante responsable.
- **Trabajo por ramas:** Ningún integrante hace `push` directo a `main` ni a `dev`. Crea una rama propia desde `dev` (`git checkout -b feat/nombre-tarea`) y abre un _Pull Request_ hacia `dev` al terminar.

### C. Comandos rápidos de Docker

- **Apagar la base de datos al terminar el día (sin borrar datos):** `docker compose stop`
- **Volver a encenderla al día siguiente:** `docker compose start`
- **Ver errores si algún script SQL falla al arrancar:** `docker compose logs db`

---

## 6. Documentación de Fase 1 y Acceso MCP Local

- **Diagrama ERE corregido:** [`docs/ER_RutasVenezuela_Corregido.drawio`](./docs/ER_RutasVenezuela_Corregido.drawio)
- **Modelo Relacional y Restricciones LPO:** [`docs/01_modelo_relacional_y_correcciones_er.md`](./docs/01_modelo_relacional_y_correcciones_er.md)
- **Plan de Trabajo Paralelo (3 integrantes):** [`docs/02_plan_equipo_segunda_entrega.md`](./docs/02_plan_equipo_segunda_entrega.md)
- **Módulo 3 · Arranque, perfiles de prueba e integración:** [`docs/03_m3_integracion.md`](./docs/03_m3_integracion.md)
- **Servidor MCP local para PostgreSQL:** [`tools/postgres_mcp_server.py`](./tools/postgres_mcp_server.py) y plantilla [`mcp_config.example.json`](./mcp_config.example.json) (solo lectura por defecto mediante `MCP_ALLOW_WRITE=false`; expone `pg_query`, `pg_list_tables`, `pg_describe_table` y `pg_list_routines`).
