# Modelo ERE Corregido, Esquema Relacional y Restricciones Explícitas — Rutas Venezuela

> **Referencias normativas:**  
> - Enunciado oficial: [`Proyectosep26ene27.pdf`](../../Proyectosep26ene27.pdf)  
> - Primera entrega: [`Primera entrega proyecto grupo 8 NRC 16375.pdf`](../../Primera%20entrega%20proyecto%20grupo%208%20NRC%2016375.pdf)  
> - Diagrama ERE corregido: [`ER_RutasVenezuela_Corregido.drawio`](./ER_RutasVenezuela_Corregido.drawio) (y copia en raíz [`ERCOMPLETODEFINITIVO_CORREGIDO.drawio`](../../ERCOMPLETODEFINITIVO_CORREGIDO.drawio))  
> - Bibliografía base: Elmasri & Navathe (7ma ed.) y láminas de cátedra de la Prof. Marlene Goncalves (`TraduccionER.pdf`, `TraduccionEER.pdf`, `EjercicioTraduccion.pdf`, `lenguaje de restricciones.pdf`, `SQL.pdf`, `PL SQL.pdf`, `PL SQL - Parte II.pdf`, `Indices.pdf`).

---

## 1. Bitácora de Correcciones al Modelo ERE

### 1.1. Observaciones de la profesora resueltas

| # | Observación recibida | Problema en la Primera Entrega | Corrección aplicada en el ERE y Modelo Relacional |
|---|---|---|---|
| **1** | *"`GUIA_TURISTICO` debería ser clave compuesta"* | `nro_rtn` y `cod_licencia` estaban subrayados por separado directamente sobre `GUIA_TURISTICO`, lo cual según Navathe representa **dos claves candidatas simples independientes** y no una clave compuesta. | Se agruparon `nro_rtn` y `cod_licencia` (sin subrayar) bajo un único atributo compuesto subrayado `id_guia`. En el modelo relacional, `Guia_Turistico` hereda `PK_GUIA_TURISTICO (id_usuario)` de `Actor_Usuario` y declara la clave alterna compuesta `AK_GUIA_TURISTICO UNIQUE (nro_rtn, cod_licencia)`. |
| **2** | *"`EXPERIENCIA_PROMOCIONAL` debería ser clave compuesta"* | `titulo` y `fecha_activacion` estaban subrayados por separado directo a la entidad (aparentando dos claves independientes). | Se agruparon `titulo` y `fecha_activacion` (sin subrayar) bajo el atributo compuesto subrayado `id_experiencia`. En el modelo relacional se mantiene `PK_EXPERIENCIA_PROMOCIONAL PRIMARY KEY (titulo, fecha_activacion)`. |
| **3** | *"Las categorías (morados) no deberían tener claves"* | Las 6 entidades de categoría (`PUNTO_ITINERARIO`, `ELEMENTO_AFECTABLE`, `OBJETO_EVALUABLE`, `ELEMENTO_SERVICIO`, `VALIDADOR_ACCESO`, `REPORTANTE`) tenían elipses de clave sustituta dibujadas en el ERE. Según `TraduccionEER.pdf` (diapositiva 9) y Elmasri & Navathe (Cap. 4/9), la clave sustituta **se agrega únicamente al traducir al modelo relacional**, nunca en el diagrama conceptual ERE. | Se eliminaron las 6 elipses clave de las entidades moradas en el diagrama ERE y se actualizó la leyenda del diagrama. Las claves sustitutas (`id_punto_itin`, `id_elem_afectable`, `id_obj_evaluable`, `id_elem_servicio`, `id_validador`, `id_reportante`) permanecen en el Modelo Relacional y en el DDL SQL. |
| **4** | *"En varias categorías de nuestro ER no se sabe cuál es la categoría (p. ej. `ELEMENTO_AFECTABLE`, `ELEMENTO_SERVICIO`: ¿Cuál es la categoría?)"* | Ninguna de las 6 categorías (`U`) ni de las 2 especializaciones (`d`) tenía el **símbolo de subconjunto** (`∪` / `∩` / `⊂` / `⊃`) exigido por Navathe y `EjercicioTraduccion.pdf`. Además, aristas largas de hasta `2700 px` cruzaban el lienzo haciendo indistinguible qué rectángulo era categoría y cuáles eran superclases. | Se colocaron todos los círculos `U` inmediatamente adyacentes a su entidad categoría morada (sin cruces), se reforzaron en morado las aristas `(U) — Categoría` y se agregó el **símbolo de subconjunto orientado con su lado abierto mirando hacia el círculo `U` o `d`** en las 6 categorías y en las 2 especializaciones. |
| **5** | *"El atributo `denominacion_oficial` de `ENTE_PUBLICO` debería ser clave"* | `denominacion_oficial` figuraba como atributo simple sin subrayar, pese a que el enunciado (pág. 5) establece explícitamente *"registrando la denominación oficial (única)"*. | Se subrayó `denominacion_oficial` en el ERE como clave alterna y se agrega `CONSTRAINT AK_ENTE_PUBLICO_DENOM UNIQUE (denominacion_oficial)` en el DDL (junto con `AK_ENTE_PUBLICO_RIF`). |
| **6** | *"El atributo `razon_social` de `COMERCIO_ALIADO` debería ser clave"* | `razon_social` figuraba como atributo simple sin subrayar, pese a que el enunciado (pág. 5) indica *"sus datos específicos abarcan la razón social (única)"*. | Se subrayó `razon_social` en el ERE como clave alterna y se agrega `CONSTRAINT AK_COMERCIO_ALIADO_RAZON UNIQUE (razon_social)` en el DDL (junto con `AK_COMERCIO_ALIADO_RIF`). |
| **7** | *"Problema aparente entre `RUTA` y `PARADA`: no llegaban a conectarse"* | Causa doble: **(a) Visual:** `RUTA` estaba aislada a `2529 px` de `COMPONE` y `3491 px` de `d`, y `PUNTO_ITINERARIO` carecía de `∪`, haciendo invisible la ruta `RUTA — COMPONE — ITINERARIO_PASO — REFIERE_A — PUNTO_ITINERARIO ∪ PARADA_TRANSPORTE`. **(b) Semántica:** El enunciado (pág. 3) exige que cada parada *"se conecta directamente con las vías transitables adyacentes, con los hitos turísticos situados en sus inmediaciones y **con las rutas urbanas que hacen uso de esa modalidad de traslado**"*, y el atributo `modalidad` estaba desconectado de `MODO_TRANSPORTE`. | **(1)** Se reubicó `RUTA` junto a `RUTA_FIJA`, `RUTA_DINAMICA`, `ITINERARIO_PASO`, `COMPONE` y `PARADA_TRANSPORTE`; **(2)** Se reemplazó el atributo de texto libre `modalidad` por la interrelación `ATIENDE_MODO (1,1 — 0,N)` entre `PARADA_TRANSPORTE` y `MODO_TRANSPORTE`; **(3)** Se añadió la interrelación M:N directa `PARADA_TRANSPORTE — SIRVE_A (0,N — 0,N) — RUTA` (tabla `Sirve_A`), manteniendo `PUNTO_ITINERARIO` para la secuencia exacta paso a paso de `Itinerario_Paso`. |

### 1.2. Ajustes de coherencia adicionales detectados durante la auditoría

1. **`HORARIO_HITO` (clave parcial compuesta):** Para mantener total consistencia con las observaciones 1 y 2, se agruparon `dia_semana` y `hora_apertura` bajo el atributo compuesto de clave parcial `clave_horario` (subrayado discontinuo).
2. **`EXPERIENCIA_PROMOCIONAL` (resolución de contradicción entre ERE/enunciado y `RR-M3-08`):** El enunciado (pág. 4) y el ERE establecen `(1,1)` tanto para `COMERCIO_ALIADO` (`PROMUEVE`) como para `GUIA_TURISTICO` (`DIRIGE`): *"Este componente se vincula con el comercio o aliado que promueve la experiencia, con el guía certificado encargado de dirigir la actividad..."*. En la Primera Entrega se había redactado por error `RR-M3-08` como XOR. Se acuerda mantener **ambos obligatorios `(1,1)`** (`id_usuario_comercio NOT NULL` e `id_usuario_guia NOT NULL`) y actualizar `RN-M3-10` / `RR-M3-08`.
3. **Eliminación de tabla duplicada en el documento previo:** En el documento de la Primera Entrega, `Tramo_Condicion` aparecía listado dos veces en la página 14; queda unificado en una sola relación.

---

## 2. Convenciones de Implementación (Cátedra Prof. Marlene Goncalves)

1. **Tipos de datos primitivos estándar (Enunciado pág. 2):** Sin extensiones espaciales (`PostGIS` prohibido). Coordenadas representadas exclusivamente con `NUMERIC(9,6)` (`latitud`, `longitud`) y `NUMERIC(8,2)` (`elevacion`, `altitud_suelo`).
2. **Nomenclatura de Constraints (`PL SQL.pdf`, págs. 31–33):**
   - Clave primaria: `PK_<tabla>`
   - Clave alterna (`UNIQUE`): `AK_<tabla>[_<col>]`
   - Clave foránea: `FK_<tabla_hija>_<tabla_padre>[_<rol>]`
   - Restricción `CHECK` de dominio (columna): `DOM_<tabla>__<columna>`
   - Restricción `CHECK` explícita (tupla/tabla): `EXP_<tabla>_R_<numero>`
3. **Nomenclatura PL/pgSQL (`PL SQL - Parte II.pdf`):**
   - Triggers: `TG_<ACCION>_<TABLA>`
   - Funciones almacenadas: `FN_<NOMBRE>`
   - Procedimientos almacenados: `SP_<NOMBRE>`
   - Variables locales `v_...`, parámetros `p_...`, registros `r_...`, cursores `c_...`.
4. **Prohibición estricta en SQL (`SELECT` / `FROM`):**
   - **Prohibido** escribir subconsultas dentro de la cláusula `SELECT` (`SELECT (SELECT ...)`) o tablas derivadas dentro de la cláusula `FROM` (`FROM (SELECT ...)`).
   - Toda consulta compleja, vista o reporte empleará vistas con nombre (`CREATE VIEW`), `JOIN` explícitos (`INNER JOIN`, `LEFT OUTER JOIN`), agrupaciones (`GROUP BY` / `HAVING`), operadores de conjuntos (`UNION`, `INTERSECT`, `EXCEPT`), subconsultas únicamente en `WHERE` (`IN`, `EXISTS`, `ANY`, `ALL`, comparación unitaria) o funciones almacenadas en `PL/pgSQL`.

---

## 3. Esquema Relacional Corregido

Se sigue el algoritmo de traducción de `TraduccionER.pdf` y `TraduccionEER.pdf`:
- **Especializaciones disjuntas totales (`ACTOR_USUARIO`, `RUTA`):** Se aplica la **Opción 1** (`TraduccionEER.pdf`, pág. 6): relación para la superclase `R_C` + relación para cada subclase `R_Ci` con la PK de `R_C` como PK y FK, más automatización vía triggers/procedimientos para garantizar disjunción y totalidad.
- **Categorías / Tipos Unión `U`:** Se aplica `TraduccionEER.pdf` (pág. 9): se crea una relación para cada categoría con una **clave sustituta** (`SERIAL` / `INTEGER GENERATED`), y se agrega dicha clave como **clave foránea única (`UNIQUE`)** en cada relación asociada a las superclases participantes, más triggers que garantizan la pertenencia exclusiva (XOR) y la integridad de participación.

### 3.0. Tablas Base de Categorías (Tipos Unión `U` — Contrato Compartido)

| Tabla | Clave Primaria | Descripción |
|---|---|---|
| `Punto_Itinerario` | `PK_PUNTO_ITINERARIO (id_punto_itin)` | Superclase unión de `Hito_Turistico` y `Parada_Transporte`. |
| `Elemento_Afectable` | `PK_ELEMENTO_AFECTABLE (id_elem_afectable)` | Superclase unión de `Hito_Turistico` y `Tramo_Via`. |
| `Objeto_Evaluable` | `PK_OBJETO_EVALUABLE (id_obj_evaluable)` | Superclase unión de `Ruta` y `Hito_Turistico`. |
| `Elemento_Servicio` | `PK_ELEMENTO_SERVICIO (id_elem_servicio)` | Superclase unión de `Hito_Turistico` y `Comercio_Aliado`. |
| `Validador_Acceso` | `PK_VALIDADOR_ACCESO (id_validador)` | Superclase unión de `Guia_Turistico` y `Comercio_Aliado`. |
| `Reportante` | `PK_REPORTANTE (id_reportante)` | Superclase unión de `Visitante`, `Guia_Turistico` y `Ente_Publico`. |

### 3.1. Módulo 1: Territorio, Hitos Turísticos y Realidad Aumentada — **Autor: José Alejandro Montes de Oca Tineo**

1. **`Estado`** `(cod_estado, nombre_estado)`
   - `PK_ESTADO (cod_estado)` · `AK_ESTADO_NOMBRE UNIQUE (nombre_estado)`
2. **`Municipio`** `(cod_estado, cod_municipio, nombre_municipio)`
   - `PK_MUNICIPIO (cod_estado, cod_municipio)`
   - `FK_MUNICIPIO_ESTADO (cod_estado) → Estado(cod_estado) ON UPDATE CASCADE ON DELETE RESTRICT`
3. **`Parroquia`** `(cod_estado, cod_municipio, cod_parroquia, nombre_parroquia, tipo_demarcacion)`
   - `PK_PARROQUIA (cod_estado, cod_municipio, cod_parroquia)`
   - `FK_PARROQUIA_MUNICIPIO (cod_estado, cod_municipio) → Municipio(cod_estado, cod_municipio) ON UPDATE CASCADE ON DELETE RESTRICT`
   - `DOM_PARROQUIA__TIPO CHECK (tipo_demarcacion IN ('Urbana', 'Rural', 'Mixta'))`
4. **`Hito_Turistico`** `(cod_estado, cod_municipio, cod_parroquia, nombre_hito, descripcion, estado_operativo, libre_acceso, estado_conservacion, latitud, longitud, elevacion, id_punto_itin, id_elem_afectable, id_obj_evaluable, id_elem_servicio)`
   - `PK_HITO_TURISTICO (cod_estado, cod_municipio, cod_parroquia, nombre_hito)` *(garantiza `RN-M1-01`)*
   - `FK_HITO_TURISTICO_PARROQUIA → Parroquia`
   - `FK_HITO_TURISTICO_PUNTO_ITIN → Punto_Itinerario` + `AK_HITO_PUNTO_ITIN UNIQUE (id_punto_itin)`
   - `FK_HITO_TURISTICO_ELEM_AFEC → Elemento_Afectable` + `AK_HITO_ELEM_AFEC UNIQUE (id_elem_afectable)`
   - `FK_HITO_TURISTICO_OBJ_EVAL → Objeto_Evaluable` + `AK_HITO_OBJ_EVAL UNIQUE (id_obj_evaluable)`
   - `FK_HITO_TURISTICO_ELEM_SERV → Elemento_Servicio` + `AK_HITO_ELEM_SERV UNIQUE (id_elem_servicio)`
   - `DOM_HITO_TURISTICO__ESTADO_OP CHECK (estado_operativo IN ('Disponible', 'En restauracion', 'Clausurado temporalmente', 'Cerrado permanentemente'))`
   - `DOM_HITO_TURISTICO__CONSERVACION CHECK (estado_conservacion IN ('Optimo', 'Bueno', 'Regular', 'Deteriorado', 'Critico'))`
   - `DOM_HITO_TURISTICO__LATITUD CHECK (latitud BETWEEN -90 AND 90)` · `DOM_HITO_TURISTICO__LONGITUD CHECK (longitud BETWEEN -180 AND 180)` · `DOM_HITO_TURISTICO__ELEVACION CHECK (elevacion >= 0)`
5. **`Categoria`** `(id_categoria, nombre_categoria, descripcion)`
   - `PK_CATEGORIA (id_categoria)` · `AK_CATEGORIA_NOMBRE UNIQUE (nombre_categoria)`
6. **`Hito_Categoria`** `(cod_estado, cod_municipio, cod_parroquia, nombre_hito, id_categoria)`
   - `PK_HITO_CATEGORIA (cod_estado, cod_municipio, cod_parroquia, nombre_hito, id_categoria)`
   - `FK_HITO_CATEGORIA_HITO → Hito_Turistico ON UPDATE CASCADE ON DELETE CASCADE`
   - `FK_HITO_CATEGORIA_CATEGORIA → Categoria ON UPDATE CASCADE ON DELETE RESTRICT`
7. **`Horario_Hito`** `(cod_estado, cod_municipio, cod_parroquia, nombre_hito, dia_semana, hora_apertura, hora_cierre)`
   - `PK_HORARIO_HITO (cod_estado, cod_municipio, cod_parroquia, nombre_hito, dia_semana, hora_apertura)`
   - `FK_HORARIO_HITO_HITO → Hito_Turistico ON UPDATE CASCADE ON DELETE CASCADE`
   - `DOM_HORARIO_HITO__DIA CHECK (dia_semana IN ('Lunes','Martes','Miercoles','Jueves','Viernes','Sabado','Domingo'))`
   - `EXP_HORARIO_HITO_R_1 CHECK (hora_cierre > hora_apertura)`
8. **`Evento_Actividad`** `(id_evento, titulo, descripcion, tipo_evento, fecha_inicio, fecha_fin)`
   - `PK_EVENTO_ACTIVIDAD (id_evento)`
   - `EXP_EVENTO_ACTIVIDAD_R_1 CHECK (fecha_fin > fecha_inicio)`
9. **`Sede_De_Evento`** `(id_evento, cod_estado, cod_municipio, cod_parroquia, nombre_hito)`
   - `PK_SEDE_DE_EVENTO (id_evento, cod_estado, cod_municipio, cod_parroquia, nombre_hito)`
   - `FK_SEDE_DE_EVENTO_EVENTO → Evento_Actividad ON DELETE CASCADE`
   - `FK_SEDE_DE_EVENTO_HITO → Hito_Turistico ON UPDATE CASCADE ON DELETE CASCADE`
10. **`Recurso_3D`** `(cod_recurso_3d, tipo_recurso, descripcion)`
    - `PK_RECURSO_3D (cod_recurso_3d)`
11. **`Punto_Anclaje_RA`** `(id_anclaje, latitud, longitud, altitud_suelo, azimut, inclinacion, rotacion, radio_activacion_m, escala, hipervinculo_info, cod_estado, cod_municipio, cod_parroquia, nombre_hito, cod_recurso_3d)`
    - `PK_PUNTO_ANCLAJE_RA (id_anclaje)`
    - `AK_PUNTO_ANCLAJE_RA_COORD UNIQUE (cod_estado, cod_municipio, cod_parroquia, nombre_hito, cod_recurso_3d, latitud, longitud, altitud_suelo)` *(garantiza `RN-M1-04`)*
    - `FK_PUNTO_ANCLAJE_RA_HITO → Hito_Turistico ON UPDATE CASCADE ON DELETE CASCADE`
    - `FK_PUNTO_ANCLAJE_RA_RECURSO → Recurso_3D ON UPDATE CASCADE ON DELETE RESTRICT`
    - `DOM_PUNTO_ANCLAJE_RA__LAT CHECK (latitud BETWEEN -90 AND 90)`, `DOM_PUNTO_ANCLAJE_RA__LON CHECK (longitud BETWEEN -180 AND 180)`, `DOM_PUNTO_ANCLAJE_RA__ALT CHECK (altitud_suelo >= 0)`, `DOM_PUNTO_ANCLAJE_RA__AZIMUT CHECK (azimut >= 0 AND azimut < 360)`, `DOM_PUNTO_ANCLAJE_RA__INCLINACION CHECK (inclinacion BETWEEN -90 AND 90)`, `DOM_PUNTO_ANCLAJE_RA__ROTACION CHECK (rotacion >= 0 AND rotacion < 360)`, `DOM_PUNTO_ANCLAJE_RA__RADIO CHECK (radio_activacion_m > 0)`, `DOM_PUNTO_ANCLAJE_RA__ESCALA CHECK (escala > 0)`

### 3.2. Módulo 2: Red Vial, Paradas, Rutas e Historiales — **Autor: Andrea Valentina Gamarra Rengifo**

*(Nota de orden de creación: `Ruta_Dinamica` referencia a `Visitante(id_usuario)` y `Ruta` referencia `Objeto_Evaluable`, por lo que `03_m3_actores.sql` se ejecuta antes que `04_m2_infraestructura_rutas.sql`.)*

1. **`Tramo_Via`** `(cod_via, nombre_via, tipo_via, longitud_m, estado_via, accesible_mov_reducida, lat_ini, lon_ini, elev_ini, lat_fin, lon_fin, elev_fin, id_elem_afectable)`
   - `PK_TRAMO_VIA (cod_via)`
   - `FK_TRAMO_VIA_ELEM_AFEC → Elemento_Afectable` + `AK_TRAMO_VIA_ELEM_AFEC UNIQUE (id_elem_afectable)`
   - `DOM_TRAMO_VIA__TIPO CHECK (tipo_via IN ('Calle','Avenida','Bulevar','Camineria','Sendero','Puente','Escalinata'))`
   - `DOM_TRAMO_VIA__ESTADO CHECK (estado_via IN ('Operativa','Restringida','Cierre total'))`
   - `DOM_TRAMO_VIA__LONGITUD CHECK (longitud_m > 0)`
   - `DOM_TRAMO_VIA__LAT_INI / LAT_FIN / LON_INI / LON_FIN / ELEV_INI / ELEV_FIN` (acotaciones geodésicas)
2. **`Condicion_Terreno`** `(cod_condicion, descripcion)`
   - `PK_CONDICION_TERRENO (cod_condicion)` · `AK_CONDICION_TERRENO_DESC UNIQUE (descripcion)`
3. **`Tramo_Condicion`** `(cod_via, cod_condicion)`
   - `PK_TRAMO_CONDICION (cod_via, cod_condicion)`
   - `FK_TRAMO_CONDICION_VIA → Tramo_Via` · `FK_TRAMO_CONDICION_COND → Condicion_Terreno`
4. **`Modo_Transporte`** `(cod_modo, nombre_modo)`
   - `PK_MODO_TRANSPORTE (cod_modo)` · `AK_MODO_TRANSPORTE_NOMBRE UNIQUE (nombre_modo)`
5. **`Tramo_Modo`** `(cod_via, cod_modo)`
   - `PK_TRAMO_MODO (cod_via, cod_modo)`
   - `FK_TRAMO_MODO_VIA → Tramo_Via` · `FK_TRAMO_MODO_MODO → Modo_Transporte`
6. **`Parada_Transporte`** `(cod_terminal, nombre_parada, cod_modo, tarifa_basica, nivel_accesibilidad, hora_apertura, hora_cierre, estado_disponibilidad, frecuencia_min, aforo_max, latitud, longitud, elevacion, techo, iluminacion_nocturna, taquilla, vigilancia, estac_transferencia, resguardo_bicicletas, id_punto_itin)`
   - `PK_PARADA_TRANSPORTE (cod_terminal)`
   - **Cambio aplicado (Obs. 7):** `cod_modo NOT NULL` + `FK_PARADA_TRANSPORTE_MODO_TRANSPORTE → Modo_Transporte(cod_modo)` (reemplaza el atributo libre `modalidad`).
   - `FK_PARADA_TRANSPORTE_PUNTO_ITIN → Punto_Itinerario` + `AK_PARADA_PUNTO_ITIN UNIQUE (id_punto_itin)`
   - `DOM_PARADA_TRANSPORTE__TARIFA CHECK (tarifa_basica >= 0)`, `DOM_PARADA_TRANSPORTE__ACCESIBILIDAD CHECK (nivel_accesibilidad BETWEEN 0 AND 5)`, `DOM_PARADA_TRANSPORTE__ESTADO CHECK (estado_disponibilidad IN ('Activa','En mantenimiento','Fuera de servicio'))`, `DOM_PARADA_TRANSPORTE__FREC CHECK (frecuencia_min > 0)`, `DOM_PARADA_TRANSPORTE__AFORO CHECK (aforo_max > 0)`, `EXP_PARADA_TRANSPORTE_R_1 CHECK (hora_cierre > hora_apertura)`
7. **`Adyacente_A`** `(cod_terminal, cod_via)`
   - `PK_ADYACENTE_A (cod_terminal, cod_via)`
   - `FK_ADYACENTE_A_PARADA → Parada_Transporte` · `FK_ADYACENTE_A_VIA → Tramo_Via`
8. **`Cerca_De`** `(cod_terminal, cod_estado, cod_municipio, cod_parroquia, nombre_hito, distancia_m)`
   - `PK_CERCA_DE (cod_terminal, cod_estado, cod_municipio, cod_parroquia, nombre_hito)`
   - `FK_CERCA_DE_PARADA → Parada_Transporte` · `FK_CERCA_DE_HITO → Hito_Turistico`
   - `DOM_CERCA_DE__DISTANCIA CHECK (distancia_m > 0)`
9. **`Ruta`** `(cod_estado, cod_municipio, nombre_ruta, duracion_estimada, mejor_horario_inicio, nivel_dificultad, ambito, tipo_ruta, id_obj_evaluable)`
   - `PK_RUTA (cod_estado, cod_municipio, nombre_ruta)`
   - `FK_RUTA_MUNICIPIO → Municipio(cod_estado, cod_municipio)`
   - `FK_RUTA_OBJ_EVAL → Objeto_Evaluable` + `AK_RUTA_OBJ_EVAL UNIQUE (id_obj_evaluable)`
   - `DOM_RUTA__DURACION CHECK (duracion_estimada > 0)`, `DOM_RUTA__DIFICULTAD CHECK (nivel_dificultad IN ('Baja','Media','Alta','Extrema'))`, `DOM_RUTA__AMBITO CHECK (ambito IN ('Urbana','Rural','Mixta'))`, `DOM_RUTA__TIPO CHECK (tipo_ruta IN ('Fija','Dinamica'))`
10. **`Ruta_Fija`** `(cod_estado, cod_municipio, nombre_ruta, experto_curador)`
    - `PK_RUTA_FIJA (cod_estado, cod_municipio, nombre_ruta)`
    - `FK_RUTA_FIJA_RUTA → Ruta ON UPDATE CASCADE ON DELETE CASCADE`
11. **`Ruta_Dinamica`** `(cod_estado, cod_municipio, nombre_ruta, id_usuario)`
    - `PK_RUTA_DINAMICA (cod_estado, cod_municipio, nombre_ruta)`
    - `FK_RUTA_DINAMICA_RUTA → Ruta ON UPDATE CASCADE ON DELETE CASCADE`
    - `FK_RUTA_DINAMICA_VISITANTE → Visitante(id_usuario) ON UPDATE CASCADE ON DELETE RESTRICT`
12. **`Prefiere_Modo`** `(cod_estado, cod_municipio, nombre_ruta, cod_modo)`
    - `PK_PREFIERE_MODO (cod_estado, cod_municipio, nombre_ruta, cod_modo)`
    - `FK_PREFIERE_MODO_RUTA_DIN → Ruta_Dinamica` · `FK_PREFIERE_MODO_MODO → Modo_Transporte`
13. **`Ruta_Categoria`** `(cod_estado, cod_municipio, nombre_ruta, id_categoria)`
    - `PK_RUTA_CATEGORIA (cod_estado, cod_municipio, nombre_ruta, id_categoria)`
    - `FK_RUTA_CATEGORIA_RUTA → Ruta` · `FK_RUTA_CATEGORIA_CAT → Categoria`
14. **`Sirve_A`** *(Nueva — Obs. 7)* `(cod_estado, cod_municipio, nombre_ruta, cod_terminal)`
    - `PK_SIRVE_A (cod_estado, cod_municipio, nombre_ruta, cod_terminal)`
    - `FK_SIRVE_A_RUTA → Ruta(cod_estado, cod_municipio, nombre_ruta) ON UPDATE CASCADE ON DELETE CASCADE`
    - `FK_SIRVE_A_PARADA → Parada_Transporte(cod_terminal) ON UPDATE CASCADE ON DELETE CASCADE`
15. **`Itinerario_Paso`** `(cod_estado, cod_municipio, nombre_ruta, nro_paso, tiempo_desde_anterior_min, id_punto_itin)`
    - `PK_ITINERARIO_PASO (cod_estado, cod_municipio, nombre_ruta, nro_paso)`
    - `FK_ITINERARIO_PASO_RUTA → Ruta ON UPDATE CASCADE ON DELETE CASCADE`
    - `FK_ITINERARIO_PASO_PUNTO → Punto_Itinerario`
    - `DOM_ITINERARIO_PASO__NRO CHECK (nro_paso >= 1)` · `DOM_ITINERARIO_PASO__TIEMPO CHECK (tiempo_desde_anterior_min >= 0)`
16. **`Recorre_Tramo`** `(cod_estado, cod_municipio, nombre_ruta, nro_paso, cod_via, orden_tramo)`
    - `PK_RECORRE_TRAMO (cod_estado, cod_municipio, nombre_ruta, nro_paso, cod_via)`
    - `AK_RECORRE_TRAMO_ORDEN UNIQUE (cod_estado, cod_municipio, nombre_ruta, nro_paso, orden_tramo)`
    - `FK_RECORRE_TRAMO_PASO → Itinerario_Paso` · `FK_RECORRE_TRAMO_VIA → Tramo_Via`
    - `DOM_RECORRE_TRAMO__ORDEN CHECK (orden_tramo >= 1)`
17. **`Historial_Recorrido`** `(id_recorrido, fecha_hora_inicio, fecha_hora_fin, completado, cod_estado, cod_municipio, nombre_ruta, id_usuario)`
    - `PK_HISTORIAL_RECORRIDO (id_recorrido)`
    - `FK_HISTORIAL_RECORRIDO_RUTA → Ruta` · `FK_HISTORIAL_RECORRIDO_VISITANTE → Visitante(id_usuario)`
    - `EXP_HISTORIAL_RECORRIDO_R_1 CHECK (fecha_hora_fin IS NULL OR fecha_hora_fin >= fecha_hora_inicio)`
18. **`Historial_Paso`** `(id_recorrido, nro_paso, fecha_hora_llegada, id_punto_itin)`
    - `PK_HISTORIAL_PASO (id_recorrido, nro_paso)`
    - `FK_HISTORIAL_PASO_HIST → Historial_Recorrido ON DELETE CASCADE` · `FK_HISTORIAL_PASO_PUNTO → Punto_Itinerario`
    - `DOM_HISTORIAL_PASO__NRO CHECK (nro_paso >= 1)`

### 3.3. Módulo 3: Actores, Experiencias Promocionales, Credenciales y Gobernanza — **Autor: Leonardo Enrique Chacón Agraz**

1. **`Actor_Usuario`** `(id_usuario, contrasena_hash, tipo_actor)`
   - `PK_ACTOR_USUARIO (id_usuario)`
   - `DOM_ACTOR_USUARIO__TIPO CHECK (tipo_actor IN ('Visitante','Guia','Comercio','Ente'))`
   *(Nota: se almacena hash criptográfico `contrasena_hash` para autenticación segura en la app web.)*
2. **`Visitante`** `(id_usuario, doc_identidad, tipo_documento, nombres, apellidos, pais_origen, idioma_nativo, tel_emergencia, grupo_sanguineo, id_reportante)`
   - `PK_VISITANTE (id_usuario)`
   - `AK_VISITANTE UNIQUE (tipo_documento, doc_identidad)` *(identificador lógico de acceso)*
   - `FK_VISITANTE_ACTOR → Actor_Usuario ON DELETE CASCADE`
   - `FK_VISITANTE_REPORTANTE → Reportante` + `AK_VISITANTE_REPORTANTE UNIQUE (id_reportante)`
   - `DOM_VISITANTE__TIPO_DOC CHECK (tipo_documento IN ('Cedula','Pasaporte'))`
   - `DOM_VISITANTE__SANGRE CHECK (grupo_sanguineo IN ('O+','O-','A+','A-','B+','B-','AB+','AB-'))`
3. **`Accesibilidad_Visitante`** `(id_usuario, accesibilidad)`
   - `PK_ACCESIBILIDAD_VISITANTE (id_usuario, accesibilidad)`
   - `FK_ACCESIBILIDAD_VISITANTE → Visitante ON DELETE CASCADE`
4. **`Guia_Turistico`** `(id_usuario, nro_rtn, cod_licencia, acreditacion_oficial, anios_trayectoria, tarifa_hora, zona_asignada, id_validador, id_reportante)`
   - `PK_GUIA_TURISTICO (id_usuario)`
   - **Cambio aplicado (Obs. 1):** `AK_GUIA_TURISTICO UNIQUE (nro_rtn, cod_licencia)`
   - `FK_GUIA_TURISTICO_ACTOR → Actor_Usuario ON DELETE CASCADE`
   - `FK_GUIA_TURISTICO_VALIDADOR → Validador_Acceso` + `AK_GUIA_VALIDADOR UNIQUE (id_validador)`
   - `FK_GUIA_TURISTICO_REPORTANTE → Reportante` + `AK_GUIA_REPORTANTE UNIQUE (id_reportante)`
   - `DOM_GUIA_TURISTICO__TRAYECTORIA CHECK (anios_trayectoria >= 0)` · `DOM_GUIA_TURISTICO__TARIFA CHECK (tarifa_hora > 0)`
5. **`Especialidad_Guia`** `(id_usuario, especialidad)`
   - `PK_ESPECIALIDAD_GUIA (id_usuario, especialidad)` · `FK_ESPECIALIDAD_GUIA_GUIA → Guia_Turistico ON DELETE CASCADE`
6. **`Idioma_Guia`** `(id_usuario, idioma)`
   - `PK_IDIOMA_GUIA (id_usuario, idioma)` · `FK_IDIOMA_GUIA_GUIA → Guia_Turistico ON DELETE CASCADE`
7. **`Adscrito_A`** `(cod_estado, cod_municipio, nombre_ruta, id_usuario)`
   - `PK_ADSCRITO_A (cod_estado, cod_municipio, nombre_ruta, id_usuario)`
   - `FK_ADSCRITO_A_RUTA → Ruta ON DELETE CASCADE` · `FK_ADSCRITO_A_GUIA → Guia_Turistico ON DELETE CASCADE`
8. **`Comercio_Aliado`** `(id_usuario, rif_comercio, razon_social, categoria_comercial, aforo, nro_permiso_sanitario, cuenta_bancaria, cod_estado, cod_municipio, cod_parroquia, nombre_hito, id_elem_servicio, id_validador)`
   - `PK_COMERCIO_ALIADO (id_usuario)`
   - `AK_COMERCIO_ALIADO_RIF UNIQUE (rif_comercio)`
   - **Cambio aplicado (Obs. 6):** `AK_COMERCIO_ALIADO_RAZON UNIQUE (razon_social)`
   - `FK_COMERCIO_ALIADO_ACTOR → Actor_Usuario ON DELETE CASCADE`
   - `FK_COMERCIO_ALIADO_HITO → Hito_Turistico` *(nullable, participación `(0,1)`)*
   - `FK_COMERCIO_ALIADO_SERV → Elemento_Servicio` + `AK_COMERCIO_SERV UNIQUE (id_elem_servicio)`
   - `FK_COMERCIO_ALIADO_VAL → Validador_Acceso` + `AK_COMERCIO_VAL UNIQUE (id_validador)`
   - `DOM_COMERCIO_ALIADO__AFORO CHECK (aforo > 0)`
9. **`Horario_Atencion_Comercio`** `(id_usuario, dia, apertura, cierre)`
   - `PK_HORARIO_ATENCION_COMERCIO (id_usuario, dia, apertura)`
   - `FK_HORARIO_COMERCIO_COMERCIO → Comercio_Aliado ON DELETE CASCADE`
   - `EXP_HORARIO_COMERCIO_R_1 CHECK (cierre > apertura)`
10. **`Ente_Publico`** `(id_usuario, rif_institucional, denominacion_oficial, nivel_territorial, funcionario_enlace, decreto_adscripcion, id_reportante)`
    - `PK_ENTE_PUBLICO (id_usuario)`
    - `AK_ENTE_PUBLICO_RIF UNIQUE (rif_institucional)`
    - **Cambio aplicado (Obs. 5):** `AK_ENTE_PUBLICO_DENOM UNIQUE (denominacion_oficial)`
    - `FK_ENTE_PUBLICO_ACTOR → Actor_Usuario ON DELETE CASCADE`
    - `FK_ENTE_PUBLICO_REPORTANTE → Reportante` + `AK_ENTE_REPORTANTE UNIQUE (id_reportante)`
    - `DOM_ENTE_PUBLICO__NIVEL CHECK (nivel_territorial IN ('Nacional','Estadal','Municipal','Parroquial'))`
11. **`Tutela`** `(id_usuario, cod_estado, cod_municipio, cod_parroquia, nombre_hito)`
    - `PK_TUTELA (id_usuario, cod_estado, cod_municipio, cod_parroquia, nombre_hito)`
    - `FK_TUTELA_ENTE → Ente_Publico ON DELETE CASCADE` · `FK_TUTELA_HITO → Hito_Turistico ON DELETE CASCADE`
12. **`Evaluacion_Experiencia`** `(cod_resena, calificacion, indice_seguridad, fecha_emision, opinion, recorrido_verificado, id_usuario, id_obj_evaluable)`
    - `PK_EVALUACION_EXPERIENCIA (cod_resena)`
    - `FK_EVALUACION_VISITANTE → Visitante(id_usuario)` · `FK_EVALUACION_OBJ_EVAL → Objeto_Evaluable`
    - `DOM_EVALUACION__CALIFICACION CHECK (calificacion BETWEEN 1 AND 5)` · `DOM_EVALUACION__SEGURIDAD CHECK (indice_seguridad BETWEEN 1 AND 5)`
    - `EXP_EVALUACION_R_1 CHECK (recorrido_verificado = TRUE)` *(la verificación de recorrido efectivo contra `Historial_Recorrido` / `Historial_Paso` / `Credencial_Acceso` se refuerza vía trigger)*
13. **`Experiencia_Promocional`** `(titulo, fecha_activacion, descripcion, precio_total, cupo_maximo, porcentaje_descuento, fecha_vencimiento, codigo_promocional, id_usuario_comercio, id_usuario_guia, cod_estado, cod_municipio, nombre_ruta)`
    - **Cambio aplicado (Obs. 2):** `PK_EXPERIENCIA_PROMOCIONAL PRIMARY KEY (titulo, fecha_activacion)`
    - `AK_EXPERIENCIA_PROMOCIONAL_COD UNIQUE (codigo_promocional)` *(cuando no es nulo)*
    - **Cambio aplicado (A2):** `id_usuario_comercio NOT NULL` (`FK_EXPERIENCIA_COMERCIO → Comercio_Aliado`) e `id_usuario_guia NOT NULL` (`FK_EXPERIENCIA_GUIA → Guia_Turistico`)
    - `FK_EXPERIENCIA_RUTA → Ruta(cod_estado, cod_municipio, nombre_ruta)`
    - `DOM_EXPERIENCIA__PRECIO CHECK (precio_total >= 0)`, `DOM_EXPERIENCIA__CUPO CHECK (cupo_maximo >= 1)`, `DOM_EXPERIENCIA__DESCUENTO CHECK (porcentaje_descuento BETWEEN 0 AND 100)`, `EXP_EXPERIENCIA_R_1 CHECK (fecha_vencimiento > fecha_activacion)`
14. **`Detalle_Experiencia`** `(titulo, fecha_activacion, nro_item, costo_individual, id_elem_servicio)`
    - `PK_DETALLE_EXPERIENCIA (titulo, fecha_activacion, nro_item)`
    - `FK_DETALLE_EXPERIENCIA_EXP → Experiencia_Promocional ON UPDATE CASCADE ON DELETE CASCADE`
    - `FK_DETALLE_EXPERIENCIA_SERV → Elemento_Servicio`
    - `DOM_DETALLE_EXPERIENCIA__NRO CHECK (nro_item >= 1)` · `DOM_DETALLE_EXPERIENCIA__COSTO CHECK (costo_individual >= 0)`
15. **`Credencial_Acceso`** `(cod_verificacion, fecha_hora_visita, monto_abonado, cant_beneficiarios, estado_pase, fecha_hora_canje, id_usuario, id_elem_servicio, id_validador)`
    - `PK_CREDENCIAL_ACCESO (cod_verificacion)`
    - `FK_CREDENCIAL_VISITANTE → Visitante(id_usuario)` · `FK_CREDENCIAL_SERVICIO → Elemento_Servicio` · `FK_CREDENCIAL_VALIDADOR → Validador_Acceso`
    - `DOM_CREDENCIAL__MONTO CHECK (monto_abonado >= 0)` · `DOM_CREDENCIAL__BENEF CHECK (cant_beneficiarios >= 1)`
    - `DOM_CREDENCIAL__ESTADO CHECK (estado_pase IN ('Emitido','Canjeado','Cancelado','Vencido'))`
    - `EXP_CREDENCIAL_R_1 CHECK ((estado_pase = 'Canjeado' AND fecha_hora_canje IS NOT NULL) OR (estado_pase <> 'Canjeado'))`
16. **`Reporte_Incidencia`** `(nro_reporte, fecha_hora_deteccion, fecha_estimada_resolucion, descripcion_evento, estado_reporte, severidad, id_reportante, id_elem_afectable, id_usuario_confirma, fecha_confirmacion, id_usuario_cierra, fecha_cierre)`
    - `PK_REPORTE_INCIDENCIA (nro_reporte)`
    - `FK_REPORTE_REPORTANTE → Reportante` · `FK_REPORTE_ELEM_AFEC → Elemento_Afectable`
    - `FK_REPORTE_ENTE_CONFIRMA → Ente_Publico(id_usuario)` · `FK_REPORTE_ENTE_CIERRA → Ente_Publico(id_usuario)`
    - `DOM_REPORTE__ESTADO CHECK (estado_reporte IN ('Preliminar','Activo','Resuelto'))`
    - `DOM_REPORTE__SEVERIDAD CHECK (severidad IN ('Bajo','Medio','Critico'))`
    - `EXP_REPORTE_R_1 CHECK (fecha_estimada_resolucion >= fecha_hora_deteccion::DATE)`
    - `EXP_REPORTE_R_2 CHECK (estado_reporte <> 'Activo' OR (id_usuario_confirma IS NOT NULL AND fecha_confirmacion IS NOT NULL))`
    - `EXP_REPORTE_R_3 CHECK (estado_reporte <> 'Resuelto' OR (id_usuario_cierra IS NOT NULL AND fecha_cierre IS NOT NULL))`
17. **`Prorroga_Incidencia`** `(nro_reporte, nro_prorroga, nueva_fecha_estimada, justificacion, fecha_registro)`
    - `PK_PRORROGA_INCIDENCIA (nro_reporte, nro_prorroga)`
    - `FK_PRORROGA_REPORTE → Reporte_Incidencia ON UPDATE CASCADE ON DELETE CASCADE`
    - `DOM_PRORROGA__NRO CHECK (nro_prorroga >= 1)`

---

## 4. Restricciones Explícitas Actualizadas (LPO) y Automatización en PostgreSQL

A continuación se documentan las restricciones nuevas o actualizadas respecto a la Primera Entrega, junto con el mecanismo de implementación en la base de datos:

| ID | Autor / Módulo | Enunciado en Lenguaje Natural | Fórmula en Lógica de Primer Orden (LPO) | Mecanismo en PostgreSQL |
|---|---|---|---|---|
| **RN-M1-08 / RR-M1-06** | José Montes de Oca (M1) | Un hito sin libre acceso debe poseer al menos un horario registrado (`RR-M1-02`), y un hito debe pertenecer al menos a una categoría (`RR-M1-04`). | $(\forall h \in \text{Hito\_Turistico} : h.\text{libre\_acceso} = \text{FALSE} \Rightarrow \exists w \in \text{Horario\_Hito} : w.\text{hito} = h) \land (\forall h \in \text{Hito\_Turistico} : \exists c \in \text{Hito\_Categoria} : c.\text{hito} = h)$ | `TRIGGER TG_VALIDAR_HITO_CATEGORIA_HORARIO` (diferido `CONSTRAINT TRIGGER` al commit / verificación en `SP_REGISTRAR_HITO`) |
| **RN-M2-11 / RR-M2-09** | Andrea Gamarra (M2) | Una parada no puede ofrecerse como punto de transbordo (`Sirve_A`) hacia una ruta si alguna de sus vías adyacentes (`Adyacente_A`) presenta cierre total o si la parada está fuera de servicio/mantenimiento. Además, la parada debe estar asociada al menos a una vía adyacente (`ADYACENTE_A` `(1,N)`). | $(\forall s \in \text{Sirve\_A}, p \in \text{Parada\_Transporte} \mid s.\text{cod\_terminal} = p.\text{cod\_terminal} : p.\text{estado\_disponibilidad} = \text{'Activa'} \land \neg(\exists a \in \text{Adyacente\_A}, v \in \text{Tramo\_Via} : a.\text{cod\_terminal} = p.\text{cod\_terminal} \land a.\text{cod\_via} = v.\text{cod\_via} \land v.\text{estado\_via} = \text{'Cierre total'}))$ | `TRIGGER TG_VALIDAR_SIRVE_A_OPERATIVIDAD` en `Sirve_A` y propagación en `TG_SINCRONIZAR_CIERRE_VIA` sobre `Tramo_Via` |
| **RN-M3-10 / RR-M3-08 *(Actualizada)*** | Leonardo Chacón (M3) | Toda experiencia promocional cuenta obligatoriamente con un comercio aliado promotor y un guía turístico certificado director. | $(\forall e \in \text{Experiencia\_Promocional} : (\exists c \in \text{Comercio\_Aliado} : e.\text{id\_usuario\_comercio} = c.\text{id\_usuario}) \land (\exists g \in \text{Guia\_Turistico} : e.\text{id\_usuario\_guia} = g.\text{id\_usuario}))$ | `NOT NULL` + `FK_EXPERIENCIA_COMERCIO` + `FK_EXPERIENCIA_GUIA` |
| **RR-M3-12** | Leonardo Chacón (M3) | Una credencial digital solo puede ser canjeada una única vez, dentro de la fecha/horario operativo autorizado del hito o comercio de servicio reservado. | $(\forall c \in \text{Credencial\_Acceso} : c.\text{estado\_pase}_{\text{old}} = \text{'Canjeado'} \Rightarrow c.\text{estado\_pase}_{\text{new}} = \text{'Canjeado'})$ y verificación contra `Horario_Hito` / `Horario_Atencion_Comercio` | `TRIGGER TG_VALIDAR_CANJE_CREDENCIAL` + `SP_CANJEAR_CREDENCIAL` |
| **RR-M3-13** | Leonardo Chacón (M3) | Disjunción total en las 6 categorías `U` (ningún identificador de categoría puede existir en más de una superclase) y correspondencia estricta en especializaciones `Actor_Usuario` y `Ruta`. | $\forall x \in \text{Cat} : \exists! S_i : x \in S_i$ | Claves foráneas `UNIQUE` en cada superclase + triggers `TG_EXCLUSIVIDAD_CATEGORIA_*` y `TG_EXCLUSIVIDAD_ACTOR` / `TG_EXCLUSIVIDAD_RUTA` |
