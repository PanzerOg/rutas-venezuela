-- ============================================================================
-- Archivo: 06_m1_vistas_indices.sql
-- Módulo: Módulo 1 - Territorio, Hitos Turísticos y Realidad Aumentada
-- Autor responsable: José Alejandro Montes de Oca Tineo - C.I. 31.066.053
-- Descripción: Vistas de consulta/reporte e índices B+-tree del Módulo 1.
--              Cumple estrictamente la regla de cátedra: CERO subconsultas en
--              SELECT y CERO subconsultas (tablas derivadas) en FROM/JOIN.
-- ============================================================================

-- 1. Vista consolidada de Ficha Integral de Hitos (CRUD y Reporte Inventario)
CREATE OR REPLACE VIEW VW_M1_FICHA_HITO AS
SELECT
    h.cod_estado,
    e.nombre_estado,
    h.cod_municipio,
    m.nombre_municipio,
    h.cod_parroquia,
    p.nombre_parroquia,
    p.tipo_demarcacion,
    e.nombre_estado || ' > ' || m.nombre_municipio || ' > ' || p.nombre_parroquia AS delimitacion_territorial,
    h.nombre_hito,
    h.descripcion,
    h.estado_operativo,
    h.libre_acceso,
    h.estado_conservacion,
    h.latitud,
    h.longitud,
    h.elevacion,
    h.id_punto_itin,
    h.id_elem_afectable,
    h.id_obj_evaluable,
    h.id_elem_servicio,
    COALESCE(STRING_AGG(DISTINCT c.nombre_categoria, ', ' ORDER BY c.nombre_categoria), 'Sin categoria') AS categorias_lista,
    COUNT(DISTINCT hh.dia_semana || '|' || hh.hora_apertura::TEXT) AS total_horarios,
    COUNT(DISTINCT se.id_evento) AS total_eventos,
    COUNT(DISTINCT pa.id_anclaje) AS total_anclajes_ra
FROM Hito_Turistico h
JOIN Parroquia p
    ON p.cod_estado = h.cod_estado
   AND p.cod_municipio = h.cod_municipio
   AND p.cod_parroquia = h.cod_parroquia
JOIN Municipio m
    ON m.cod_estado = p.cod_estado
   AND m.cod_municipio = p.cod_municipio
JOIN Estado e
    ON e.cod_estado = m.cod_estado
LEFT JOIN Hito_Categoria hc
    ON hc.cod_estado = h.cod_estado
   AND hc.cod_municipio = h.cod_municipio
   AND hc.cod_parroquia = h.cod_parroquia
   AND hc.nombre_hito = h.nombre_hito
LEFT JOIN Categoria c
    ON c.id_categoria = hc.id_categoria
LEFT JOIN Horario_Hito hh
    ON hh.cod_estado = h.cod_estado
   AND hh.cod_municipio = h.cod_municipio
   AND hh.cod_parroquia = h.cod_parroquia
   AND hh.nombre_hito = h.nombre_hito
LEFT JOIN Sede_De_Evento se
    ON se.cod_estado = h.cod_estado
   AND se.cod_municipio = h.cod_municipio
   AND se.cod_parroquia = h.cod_parroquia
   AND se.nombre_hito = h.nombre_hito
LEFT JOIN Punto_Anclaje_RA pa
    ON pa.cod_estado = h.cod_estado
   AND pa.cod_municipio = h.cod_municipio
   AND pa.cod_parroquia = h.cod_parroquia
   AND pa.nombre_hito = h.nombre_hito
GROUP BY
    h.cod_estado,
    e.nombre_estado,
    h.cod_municipio,
    m.nombre_municipio,
    h.cod_parroquia,
    p.nombre_parroquia,
    p.tipo_demarcacion,
    h.nombre_hito,
    h.descripcion,
    h.estado_operativo,
    h.libre_acceso,
    h.estado_conservacion,
    h.latitud,
    h.longitud,
    h.elevacion,
    h.id_punto_itin,
    h.id_elem_afectable,
    h.id_obj_evaluable,
    h.id_elem_servicio;

-- 2. Vista para Reporte Estratégico M1 (Inventario Patrimonial y Estado de Conservación)
CREATE OR REPLACE VIEW VW_M1_INVENTARIO_PATRIMONIAL AS
SELECT
    cod_estado,
    nombre_estado,
    cod_municipio,
    nombre_municipio,
    cod_parroquia,
    nombre_parroquia,
    delimitacion_territorial,
    nombre_hito,
    descripcion,
    estado_operativo,
    estado_conservacion,
    libre_acceso,
    CASE WHEN libre_acceso THEN 'Si' ELSE 'No' END AS libre_acceso_texto,
    elevacion,
    latitud,
    longitud,
    categorias_lista,
    total_horarios,
    total_eventos,
    total_anclajes_ra
FROM VW_M1_FICHA_HITO;

-- 3. Vista desglosada por categoría para filtros sin subconsultas derivadas
CREATE OR REPLACE VIEW VW_M1_INVENTARIO_PATRIMONIAL_CAT AS
SELECT
    v.cod_estado,
    v.nombre_estado,
    v.cod_municipio,
    v.nombre_municipio,
    v.cod_parroquia,
    v.nombre_parroquia,
    v.delimitacion_territorial,
    v.nombre_hito,
    v.descripcion,
    v.estado_operativo,
    v.estado_conservacion,
    v.libre_acceso,
    v.libre_acceso_texto,
    v.elevacion,
    v.latitud,
    v.longitud,
    v.categorias_lista,
    c.id_categoria,
    c.nombre_categoria
FROM VW_M1_INVENTARIO_PATRIMONIAL v
JOIN Hito_Categoria hc
    ON hc.cod_estado = v.cod_estado
   AND hc.cod_municipio = v.cod_municipio
   AND hc.cod_parroquia = v.cod_parroquia
   AND hc.nombre_hito = v.nombre_hito
JOIN Categoria c
    ON c.id_categoria = hc.id_categoria;

-- 4. Vista de Consulta Patrimonial (M1):
--    Monumentos históricos no de libre acceso con horarios disponibles en fines de semana
CREATE OR REPLACE VIEW VW_M1_CONSULTA_PATRIMONIAL_FDS AS
SELECT
    h.cod_estado,
    e.nombre_estado,
    h.cod_municipio,
    m.nombre_municipio,
    h.cod_parroquia,
    p.nombre_parroquia,
    h.nombre_hito,
    h.estado_operativo,
    h.estado_conservacion,
    h.libre_acceso,
    c.nombre_categoria,
    hh.dia_semana,
    hh.hora_apertura,
    hh.hora_cierre
FROM Hito_Turistico h
JOIN Parroquia p
    ON p.cod_estado = h.cod_estado
   AND p.cod_municipio = h.cod_municipio
   AND p.cod_parroquia = h.cod_parroquia
JOIN Municipio m
    ON m.cod_estado = p.cod_estado
   AND m.cod_municipio = p.cod_municipio
JOIN Estado e
    ON e.cod_estado = m.cod_estado
JOIN Hito_Categoria hc
    ON hc.cod_estado = h.cod_estado
   AND hc.cod_municipio = h.cod_municipio
   AND hc.cod_parroquia = h.cod_parroquia
   AND hc.nombre_hito = h.nombre_hito
JOIN Categoria c
    ON c.id_categoria = hc.id_categoria
JOIN Horario_Hito hh
    ON hh.cod_estado = h.cod_estado
   AND hh.cod_municipio = h.cod_municipio
   AND hh.cod_parroquia = h.cod_parroquia
   AND hh.nombre_hito = h.nombre_hito
WHERE c.nombre_categoria = 'Monumento Historico'
  AND h.libre_acceso = FALSE
  AND h.estado_operativo = 'Disponible'
  AND hh.dia_semana IN ('Sabado', 'Domingo');

-- 5. Vista de Catálogo de Realidad Aumentada
CREATE OR REPLACE VIEW VW_M1_ANCLAJES_RA_CATALOGO AS
SELECT
    pa.id_anclaje,
    pa.latitud,
    pa.longitud,
    pa.altitud_suelo,
    pa.azimut,
    pa.inclinacion,
    pa.rotacion,
    pa.radio_activacion_m,
    pa.escala,
    pa.hipervinculo_info,
    pa.cod_estado,
    e.nombre_estado,
    pa.cod_municipio,
    m.nombre_municipio,
    pa.cod_parroquia,
    p.nombre_parroquia,
    pa.nombre_hito,
    h.estado_operativo AS estado_hito,
    pa.cod_recurso_3d,
    r.tipo_recurso,
    r.descripcion AS descripcion_recurso
FROM Punto_Anclaje_RA pa
JOIN Recurso_3D r
    ON r.cod_recurso_3d = pa.cod_recurso_3d
JOIN Hito_Turistico h
    ON h.cod_estado = pa.cod_estado
   AND h.cod_municipio = pa.cod_municipio
   AND h.cod_parroquia = pa.cod_parroquia
   AND h.nombre_hito = pa.nombre_hito
JOIN Parroquia p
    ON p.cod_estado = h.cod_estado
   AND p.cod_municipio = h.cod_municipio
   AND p.cod_parroquia = h.cod_parroquia
JOIN Municipio m
    ON m.cod_estado = p.cod_estado
   AND m.cod_municipio = p.cod_municipio
JOIN Estado e
    ON e.cod_estado = m.cod_estado;

-- 6. Vista de Agenda Cultural y Sedes
CREATE OR REPLACE VIEW VW_M1_AGENDA_EVENTOS AS
SELECT
    ev.id_evento,
    ev.titulo,
    ev.descripcion,
    ev.tipo_evento,
    ev.fecha_inicio,
    ev.fecha_fin,
    se.cod_estado,
    e.nombre_estado,
    se.cod_municipio,
    m.nombre_municipio,
    se.cod_parroquia,
    p.nombre_parroquia,
    se.nombre_hito,
    h.estado_operativo
FROM Evento_Actividad ev
LEFT JOIN Sede_De_Evento se
    ON se.id_evento = ev.id_evento
LEFT JOIN Hito_Turistico h
    ON h.cod_estado = se.cod_estado
   AND h.cod_municipio = se.cod_municipio
   AND h.cod_parroquia = se.cod_parroquia
   AND h.nombre_hito = se.nombre_hito
LEFT JOIN Parroquia p
    ON p.cod_estado = h.cod_estado
   AND p.cod_municipio = h.cod_municipio
   AND p.cod_parroquia = h.cod_parroquia
LEFT JOIN Municipio m
    ON m.cod_estado = p.cod_estado
   AND m.cod_municipio = p.cod_municipio
LEFT JOIN Estado e
    ON e.cod_estado = m.cod_estado;

-- Índices B+-tree para acelerar búsquedas frecuentes (Indices.pdf)
CREATE INDEX IDX_M1_HITO_ESTADO_CONSERV
    ON Hito_Turistico (estado_operativo, estado_conservacion, libre_acceso);

CREATE INDEX IDX_M1_HITO_COORDS_3D
    ON Hito_Turistico (latitud, longitud, elevacion);

CREATE INDEX IDX_M1_HITO_CATEGORIA_CAT
    ON Hito_Categoria (id_categoria);

CREATE INDEX IDX_M1_HORARIO_DIA
    ON Horario_Hito (dia_semana, hora_apertura, hora_cierre);

CREATE INDEX IDX_M1_EVENTO_FECHAS
    ON Evento_Actividad (fecha_inicio, fecha_fin);

CREATE INDEX IDX_M1_ANCLAJE_RA_COORDS
    ON Punto_Anclaje_RA (latitud, longitud, altitud_suelo);

CREATE INDEX IDX_M1_ANCLAJE_RA_RECURSO
    ON Punto_Anclaje_RA (cod_recurso_3d);
