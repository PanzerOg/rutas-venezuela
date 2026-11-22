# Plan de Trabajo Paralelo y Sin Conflictos — Segunda Entrega (Rutas Venezuela)

> **Integrantes y Módulos (continuidad con Primera Entrega):**
> - **Módulo 1 (Patrimonio, Territorio y Realidad Aumentada):** José Alejandro Montes de Oca Tineo
> - **Módulo 2 (Infraestructura Vial, Paradas, Rutas e Historiales):** Andrea Valentina Gamarra Rengifo
> - **Módulo 3 (Actores, Seguridad Lógica, Experiencias, Credenciales e Incidencias):** Leonardo Enrique Chacón Agraz

---

## 1. Estrategia para Trabajar Sin Obstruirse

La principal fuente de bloqueos y conflictos de `git merge` ocurre cuando dos personas editan el mismo archivo SQL o dependen de tablas que el otro aún no ha creado. Para eliminarlo por completo, el proyecto se organiza bajo **tres principios**:

1. **Propiedad exclusiva de archivos por módulo:** Cada carpeta (`database/`, `backend/app/routers/`, `frontend/js/modules/`, `reports/`) tiene archivos separados por integrante (`m1_*`, `m2_*`, `m3_*`). Ningún integrante modifica archivos de otro módulo.
2. **Paso 0 — Contratos congelados:** Antes de empezar la implementación paralela, se congelan las 6 tablas base de categorías (`01_categorias_base.sql`), los nombres de las tablas/PKs definidas en [`01_modelo_relacional_y_correcciones_er.md`](./01_modelo_relacional_y_correcciones_er.md), el formato JSON de paginado/ordenamiento/búsqueda y las rutas base de la API REST.
3. **Orden DAG sin ciclos en `database/`:** Gracias a la separación de `03_m3_actores.sql` (tablas de actores) respecto a `05_m3_transacciones_gobernanza.sql` (tablas transaccionales que dependen de M1 y M2), las dependencias forman un grafo acíclico estricto:

```
00_drop_all.sql
  └── 01_categorias_base.sql              (Contrato congelado: 6 categorías U)
        ├── 02_m1_territorio_hitos_ra.sql (José - M1)
        │     └── 03_m3_actores.sql       (Leonardo - M3: referencia Hito_Turistico en Comercio y Tutela)
        │           └── 04_m2_infraestructura_rutas.sql  (Andrea - M2: referencia Municipio, Visitante, Categoria)
        │                 └── 05_m3_transacciones_gobernanza.sql (Leonardo - M3: referencia Ruta, Hito, Actores)
        └── 06/07/08_*_vistas_indices.sql (José, Andrea, Leonardo en paralelo)
```

---

## 2. Matriz de Propiedad Exclusiva de Archivos

### 2.1. Base de Datos (`rutas-venezuela/database/`)

| Carpeta | Archivo | Responsable | Contenido / Alcance |
|---|---|---|---|
| `database/` | `00_init.sh` | Base común | Ejecutor ordenado de subcarpetas `01_ddl` → `02_security` → `03_logic` → `04_seeds`. |
| `01_ddl/` | `00_drop_all.sql` | Base común | `DROP VIEW`, `DROP TABLE ... CASCADE`, `DROP FUNCTION/PROCEDURE` para reinicio limpio. |
| `01_ddl/` | `01_categorias_base.sql` | Base común | 6 tablas de categorías (`Punto_Itinerario`, `Elemento_Afectable`, `Objeto_Evaluable`, `Elemento_Servicio`, `Validador_Acceso`, `Reportante`). |
| `01_ddl/` | `02_m1_territorio_hitos_ra.sql` | **José (M1)** | `Estado`, `Municipio`, `Parroquia`, `Hito_Turistico`, `Categoria`, `Hito_Categoria`, `Horario_Hito`, `Evento_Actividad`, `Sede_De_Evento`, `Recurso_3D`, `Punto_Anclaje_RA` + constraints `PK_`, `AK_`, `FK_`, `DOM_`, `EXP_`. |
| `01_ddl/` | `03_m3_actores.sql` | **Leonardo (M3)** | `Actor_Usuario`, `Visitante`, `Accesibilidad_Visitante`, `Guia_Turistico`, `Especialidad_Guia`, `Idioma_Guia`, `Adscrito_A` *(o en `05_` tras `Ruta`)*, `Comercio_Aliado`, `Horario_Atencion_Comercio`, `Ente_Publico`, `Tutela`. *(Nota: `Adscrito_A` referencia `Ruta`, por lo que vive en `05_m3_transacciones_gobernanza.sql` para preservar el DAG).* |
| `01_ddl/` | `04_m2_infraestructura_rutas.sql` | **Andrea (M2)** | `Tramo_Via`, `Condicion_Terreno`, `Tramo_Condicion`, `Modo_Transporte`, `Tramo_Modo`, `Parada_Transporte` (con `cod_modo`), `Adyacente_A`, `Cerca_De`, `Ruta`, `Ruta_Fija`, `Ruta_Dinamica`, `Prefiere_Modo`, `Ruta_Categoria`, `Sirve_A`, `Itinerario_Paso`, `Recorre_Tramo`, `Historial_Recorrido`, `Historial_Paso`. |
| `01_ddl/` | `05_m3_transacciones_gobernanza.sql` | **Leonardo (M3)** | `Adscrito_A`, `Evaluacion_Experiencia`, `Experiencia_Promocional`, `Detalle_Experiencia`, `Credencial_Acceso`, `Reporte_Incidencia`, `Prorroga_Incidencia`. |
| `01_ddl/` | `06_m1_vistas_indices.sql` | **José (M1)** | Vistas de consulta/reporte M1 + índices B+-tree de búsqueda territorial/RA. |
| `01_ddl/` | `07_m2_vistas_indices.sql` | **Andrea (M2)** | Vistas de consulta/reporte M2 + índices de vías, paradas y rutas. |
| `01_ddl/` | `08_m3_vistas_indices.sql` | **Leonardo (M3)** | Vistas de consulta/reporte M3 + índices de experiencias, credenciales e incidencias. |
| `02_security/` | `01_roles_y_cuentas.sql` | **Leonardo (M3)** | Roles del SGBD (`rol_visitante`, `rol_guia`, `rol_comercio`, `rol_ente_publico`, `rol_admin_rutas`, `rol_reportes`), cuentas de servicio y privilegios de sistema (`CONNECT`, `USAGE ON SCHEMA`). |
| `02_security/` | `02_m1_privilegios.sql` | **José (M1)** | `GRANT` / `REVOKE` de objeto por rol sobre tablas, vistas y rutinas del Módulo 1. |
| `02_security/` | `03_m2_privilegios.sql` | **Andrea (M2)** | `GRANT` / `REVOKE` de objeto por rol sobre tablas, vistas y rutinas del Módulo 2. |
| `02_security/` | `04_m3_privilegios.sql` | **Leonardo (M3)** | `GRANT` / `REVOKE` de objeto por rol sobre tablas, vistas y rutinas del Módulo 3. |
| `03_logic/` | `01_m1_plpgsql.sql` | **José (M1)** | Triggers, funciones (`FN_DISTANCIA_3D_METROS`, `FN_RECURSOS_RA_CERCANOS`, etc.) y procedimientos (`SP_REGISTRAR_HITO`, `SP_ASIGNAR_EVENTO_HITO`, etc.) de M1. |
| `03_logic/` | `02_m2_plpgsql.sql` | **Andrea (M2)** | Triggers (`TG_SINCRONIZAR_CIERRE_VIA`, `TG_CONTINUIDAD_ITINERARIO`, `TG_VALIDAR_SIRVE_A`), funciones (`FN_DESNIVEL_TRAMO`, `FN_TIEMPO_ACUMULADO_PASO`, `FN_RUTA_ACCESIBLE_UNIVERSAL`, `FN_PARADAS_TRANSBORDO_5KM`) y `SP_GENERAR_RUTA_ACCESIBLE`. |
| `03_logic/` | `03_m3_plpgsql.sql` | **Leonardo (M3)** | Triggers (disjunción de actores/categorías, estado preliminar/activo/resuelto de incidencias, prórroga mayor a fecha actual, verificación de recorrido antes de evaluar, canje único en horario válido) y procedimientos (`SP_CANJEAR_CREDENCIAL`, `SP_CONFIRMAR_INCIDENCIA`, `SP_PRORROGAR_INCIDENCIA`, `SP_CERRAR_INCIDENCIA`). |
| `04_seeds/` | `01_m1_seeds.sql` | **José (M1)** | Datos realistas venezolanos: estados, municipios homónimos (`Sucre`, `Libertador`), parroquias (`San José`, `Catedral`, `Chacao`), hitos patrimoniales, horarios, eventos y anclajes RA. |
| `04_seeds/` | `02_m3_actores_seeds.sql` | **Leonardo (M3)** | Visitantes, guías certificados, comercios aliados y entes públicos patrimoniales reales/coherentes. |
| `04_seeds/` | `03_m2_seeds.sql` | **Andrea (M2)** | Tramos viales, condiciones de terreno, modos, paradas (Metro de Caracas, Trolebús Mérida, TransMaracaibo, Teleférico), `Adyancente_A`, `Cerca_De`, rutas fijas y dinámicas (`Ruta del Cacao` en Sucre/Miranda/Barinas), `Sirve_A`, pasos e historiales. |
| `04_seeds/` | `04_m3_transacciones_seeds.sql` | **Leonardo (M3)** | Experiencias promocionales + detalles, credenciales digitales (emitidas/canjeadas/canceladas/vencidas), reportes de incidencia (preliminares/activos/resueltos) + prórrogas, y evaluaciones verificadas. |

### 2.2. Aplicación Web y Reportes Jaspersoft

| Capa | Archivo / Carpeta | Responsable | Notas de aislamiento |
|---|---|---|---|
| Backend Core | `backend/app/main.py`, `db.py`, `deps.py` | Base común | Pool `psycopg2`, lectura `.env`, autenticación por rol DB, paginado/ordenamiento estándar. |
| Backend Routers | `backend/app/routers/auth.py` | **Leonardo (M3)** | Login por identificador (Cédula, RTN+Licencia, RIF) + contraseña y perfilamiento. |
| Backend Routers | `backend/app/routers/m1_patrimonio.py` | **José (M1)** | CRUD territorial/hitos/horarios/eventos/RA + Consultas 1, 2 y 5 + Reporte 1. |
| Backend Routers | `backend/app/routers/m2_infraestructura.py` | **Andrea (M2)** | CRUD vías/paradas/rutas/itinerarios/historiales + Consultas 3 y 6 + RF-VA-02 + Reporte 2. |
| Backend Routers | `backend/app/routers/m3_transacciones.py` | **Leonardo (M3)** | CRUD actores/experiencias/credenciales/incidencias/evaluaciones + Consultas 4 y 7 + RF-VA-03 + Reporte 3. |
| Backend Reports | `backend/app/routers/reportes.py` | Base común | Exportación CSV/PDF/JSON y enlace a plantillas Jaspersoft. |
| Frontend Shared | `frontend/index.html`, `js/api.js`, `js/components/dataTable.js` | Base común | Componente reutilizable de tabla con **paginado**, **ordenamiento dinámico por columnas** y **búsqueda avanzada multicriterio**. |
| Frontend Modules | `frontend/js/modules/m1_patrimonio.js` | **José (M1)** | Vistas CRUD M1, Visor RA (simulador/cálculo 3D), Reporte Inventario Patrimonial. |
| Frontend Modules | `frontend/js/modules/m2_infraestructura.js` | **Andrea (M2)** | Vistas CRUD M2, Motor de Ruteo Accesible, Reporte Conectividad y Aforo. |
| Frontend Modules | `frontend/js/modules/m3_transacciones.js` | **Leonardo (M3)** | Vistas CRUD M3, Canje de Credenciales, Flujo de Incidencias/Prórrogas, Observatorio de Severidad. |
| Jaspersoft JRXML | `reports/01_m1_inventario_patrimonial.jrxml` | **José (M1)** | Reporte estratégico M1 (Inventario Patrimonial y Estado de Conservación). |
| Jaspersoft JRXML | `reports/02_m2_conectividad_aforo_transbordos.jrxml` | **Andrea (M2)** | Reporte estratégico M2 (Matriz de Conectividad y Aforo de Transbordos). |
| Jaspersoft JRXML | `reports/03_m3_observatorio_incidencias.jrxml` | **Leonardo (M3)** | Reporte estratégico M3 (Observatorio de Severidad de Incidencias Institucionales). |
| Guía Jaspersoft | `docs/03_guia_jaspersoft.md` | Base común | Instalación de Jaspersoft Studio, driver JDBC PostgreSQL y compilación de los 3 `.jrxml`. |

---

## 3. Contratos Congelados (Paso 0)

1. **Paginado, ordenamiento y búsqueda en Backend (`GET /api/m{1,2,3}/...`):**
   - Query params estándar: `page` (default `1`), `page_size` (default `10`, máx `100`), `sort_by` (lista blanca de columnas por endpoint para evitar inyección SQL), `sort_dir` (`asc` | `desc`), más filtros avanzados específicos.
   - Respuesta JSON estándar:
     ```json
     {
       "items": [],
       "total": 0,
       "page": 1,
       "page_size": 10,
       "total_pages": 1,
       "sort_by": "...",
       "sort_dir": "asc"
     }
     ```
2. **Prohibición SQL en toda la capa backend, vistas y JRXML:**
   - Cero `SELECT (SELECT ...)` ni `FROM (SELECT ...)` en consultas SQL.
   - Toda consulta paginada y filtrada ejecuta SQL parametrizado contra tablas o `VIEW`s con nombre usando `LIMIT %s OFFSET %s` y `ORDER BY` validado por diccionario de columnas permitidas.
3. **Encabezado obligatorio de autoría en cada `.sql`, `.py`, `.js` y `.jrxml`:**
   ```sql
   -- ============================================================================
   -- Archivo: <nombre_archivo>
   -- Módulo: <Módulo X>
   -- Autor responsable: <Nombre Completo - C.I.>
   -- ============================================================================
   ```

---

## 4. Trazabilidad Completa de Requisitos (Segunda Entrega)

| Requisito / Entregable | Responsable | Archivos involucrados |
|---|---|---|
| **RF-CRUD-01..04** (Territorio, Hitos, RA, Horarios/Eventos) + **RF-VA-01** + **Consultas 1, 2, 5** | **José Montes de Oca (M1)** | `02_m1_*.sql`, `06_m1_*.sql`, `01_m1_plpgsql.sql`, `01_m1_seeds.sql`, `m1_patrimonio.py`, `m1_patrimonio.js` |
| **Reporte 1** (Inventario Patrimonial y Estado de Conservación) | **José Montes de Oca (M1)** | `06_m1_vistas_indices.sql`, `01_m1_inventario_patrimonial.jrxml`, `m1_patrimonio.js` |
| **RF-CRUD-05..08** (Vías, Paradas, Rutas/Itinerarios/Sirve_A, Historiales) + **RF-VA-02** + **Consultas 3, 6** | **Andrea Gamarra (M2)** | `04_m2_*.sql`, `07_m2_*.sql`, `02_m2_plpgsql.sql`, `03_m2_seeds.sql`, `m2_infraestructura.py`, `m2_infraestructura.js` |
| **Reporte 2** (Matriz de Conectividad y Aforo de Transbordos) | **Andrea Gamarra (M2)** | `07_m2_vistas_indices.sql`, `02_m2_conectividad_aforo_transbordos.jrxml`, `m2_infraestructura.js` |
| **RF-CRUD-09..13** (Actores, Experiencias, Credenciales, Incidencias, Evaluaciones) + **RF-VA-03** + **Consultas 4, 7** | **Leonardo Chacón (M3)** | `03_m3_*.sql`, `05_m3_*.sql`, `08_m3_*.sql`, `03_m3_plpgsql.sql`, `02/04_m3_*_seeds.sql`, `m3_transacciones.py`, `m3_transacciones.js` |
| **Reporte 3** (Observatorio de Severidad de Incidencias Institucionales) | **Leonardo Chacón (M3)** | `08_m3_vistas_indices.sql`, `03_m3_observatorio_incidencias.jrxml`, `m3_transacciones.js` |
| **Seguridad Lógica** (Roles, cuentas, privilegios de sistema y de objeto) | **Leonardo (base/M3)** + **José (M1)** + **Andrea (M2)** | `02_security/01..04_*.sql` |

---

## 5. Flujo Git Sugerido (Sin Conflictos)

1. Crear ramas independientes desde `dev`:
   - `git checkout -b feat/m1-base-datos-y-api` (José)
   - `git checkout -b feat/m2-base-datos-y-api` (Andrea)
   - `git checkout -b feat/m3-base-datos-y-api` (Leonardo)
2. Orden de integración por hitos hacia `dev`:
   - **Hito 1 (DDL + Seguridad):** Integrar `01_categorias_base.sql` → `02_m1` → `03_m3` → `04_m2` → `05_m3` → `02_security/*`. Verificar con `docker compose down -v && docker compose up -d`.
   - **Hito 2 (PL/pgSQL + Seeds):** Integrar `03_logic/*` y `04_seeds/*`. Verificar que los triggers no bloquean cargas válidas y rechazan violaciones.
   - **Hito 3 (Backend + Frontend + Jaspersoft):** Cada integrante desarrolla su router, módulo JS y `.jrxml` en paralelo contra la base ya poblada, integrando por Pull Request a `dev`.
