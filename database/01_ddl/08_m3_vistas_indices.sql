-- Módulo 3 · Autor responsable: Leonardo Enrique Chacón Agraz - C.I. 31.895.402
BEGIN;

DO $$
BEGIN
    IF to_regclass('public.tramo_via') IS NOT NULL THEN
        EXECUTE 'CREATE VIEW VW_M3_TRAMOS AS SELECT id_elem_afectable, cod_via::TEXT, nombre_via::TEXT FROM Tramo_Via';
    ELSE
        CREATE VIEW VW_M3_TRAMOS AS
        SELECT NULL::INTEGER AS id_elem_afectable, NULL::TEXT AS cod_via, NULL::TEXT AS nombre_via WHERE FALSE;
    END IF;
    IF to_regclass('public.ruta') IS NOT NULL THEN
        EXECUTE 'CREATE VIEW VW_M3_RUTAS AS SELECT cod_estado, cod_municipio, nombre_ruta, id_obj_evaluable FROM Ruta';
    ELSE
        CREATE VIEW VW_M3_RUTAS AS
        SELECT NULL::VARCHAR AS cod_estado, NULL::VARCHAR AS cod_municipio, NULL::VARCHAR AS nombre_ruta,
               NULL::INTEGER AS id_obj_evaluable WHERE FALSE;
    END IF;
END;
$$;

CREATE VIEW VW_M3_AUTH AS
SELECT a.id_usuario, a.tipo_actor, a.contrasena_hash, v.doc_identidad::TEXT AS identificador,
       v.tipo_documento::TEXT AS complemento, concat_ws(' ', v.nombres, v.apellidos) AS nombre
FROM Actor_Usuario a JOIN Visitante v USING (id_usuario)
UNION ALL
SELECT a.id_usuario, a.tipo_actor, a.contrasena_hash, g.nro_rtn, g.cod_licencia, 'Guía ' || g.nro_rtn
FROM Actor_Usuario a JOIN Guia_Turistico g USING (id_usuario)
UNION ALL
SELECT a.id_usuario, a.tipo_actor, a.contrasena_hash, c.rif_comercio, NULL, c.razon_social
FROM Actor_Usuario a JOIN Comercio_Aliado c USING (id_usuario)
UNION ALL
SELECT a.id_usuario, a.tipo_actor, a.contrasena_hash, e.rif_institucional, NULL, e.denominacion_oficial
FROM Actor_Usuario a JOIN Ente_Publico e USING (id_usuario);

CREATE VIEW VW_M3_ACTORES AS
SELECT id_usuario, tipo_actor, identificador, complemento, nombre FROM VW_M3_AUTH;

CREATE VIEW VW_M3_SERVICIOS AS
SELECT id_elem_servicio, nombre_hito::TEXT AS servicio, 'Hito'::TEXT AS tipo, cod_estado, cod_municipio, cod_parroquia
FROM Hito_Turistico
UNION ALL
SELECT id_elem_servicio, razon_social, 'Comercio', cod_estado, cod_municipio, cod_parroquia
FROM Comercio_Aliado;

CREATE VIEW VW_M3_VALIDADORES AS
SELECT id_validador, id_usuario, 'Guia'::TEXT AS tipo, 'Guía ' || nro_rtn AS validador
FROM Guia_Turistico
UNION ALL
SELECT id_validador, id_usuario, 'Comercio', razon_social FROM Comercio_Aliado;

CREATE VIEW VW_M3_EVALUABLES AS
SELECT id_obj_evaluable, nombre_hito::TEXT AS objeto, 'Hito'::TEXT AS tipo, cod_estado, cod_municipio, cod_parroquia
FROM Hito_Turistico
UNION ALL
SELECT id_obj_evaluable, nombre_ruta, 'Ruta', cod_estado, cod_municipio, NULL FROM VW_M3_RUTAS;

CREATE VIEW VW_M3_AFECTABLES AS
SELECT id_elem_afectable, nombre_hito::TEXT AS elemento, 'Hito'::TEXT AS tipo, cod_estado, cod_municipio,
       cod_parroquia, nombre_hito
FROM Hito_Turistico
UNION ALL
SELECT id_elem_afectable, nombre_via, 'Tramo', NULL, NULL, NULL, NULL FROM VW_M3_TRAMOS;

CREATE VIEW VW_M3_REPORTANTES AS
SELECT id_reportante, id_usuario, 'Visitante'::TEXT AS tipo FROM Visitante
UNION ALL
SELECT id_reportante, id_usuario, 'Guia' FROM Guia_Turistico
UNION ALL
SELECT id_reportante, id_usuario, 'Ente' FROM Ente_Publico;

CREATE VIEW VW_M3_EXPERIENCIAS AS
SELECT x.*, c.razon_social AS comercio, g.nro_rtn AS guia_rtn,
       ((statement_timestamp() AT TIME ZONE 'America/Caracas')::DATE
        BETWEEN x.fecha_activacion AND x.fecha_vencimiento) AS vigente
FROM Experiencia_Promocional x
JOIN Comercio_Aliado c ON c.id_usuario = x.id_usuario_comercio
JOIN Guia_Turistico g ON g.id_usuario = x.id_usuario_guia;

CREATE VIEW VW_M3_CREDENCIALES AS
SELECT c.*, s.servicio, s.tipo AS tipo_servicio, v.validador, v.tipo AS tipo_validador,
       v.id_usuario AS usuario_validador,
       CASE WHEN c.estado_pase = 'Emitido'
              AND c.fecha_hora_visita < (statement_timestamp() AT TIME ZONE 'America/Caracas')
            THEN 'Vencido' ELSE c.estado_pase END AS estado_efectivo
FROM Credencial_Acceso c
JOIN VW_M3_SERVICIOS s USING (id_elem_servicio)
JOIN VW_M3_VALIDADORES v USING (id_validador)
WHERE current_user = 'rol_admin_rutas'
   OR c.id_usuario = nullif(current_setting('rutas.id_usuario', TRUE), '')::INTEGER
   OR v.id_usuario = nullif(current_setting('rutas.id_usuario', TRUE), '')::INTEGER;

CREATE VIEW VW_M3_EVALUACIONES AS
SELECT e.*, o.objeto, o.cod_estado, o.cod_municipio, o.tipo AS tipo_objeto,
       v.nombres || ' ' || left(v.apellidos, 1) || '.' AS visitante
FROM Evaluacion_Experiencia e
JOIN VW_M3_EVALUABLES o USING (id_obj_evaluable)
JOIN Visitante v USING (id_usuario);

CREATE VIEW VW_M3_CALIDAD_RUTA AS
SELECT cod_estado, cod_municipio, objeto AS nombre_ruta, COUNT(*) AS total,
       ROUND(AVG(calificacion), 2) AS calificacion_promedio,
       ROUND(AVG(indice_seguridad), 2) AS seguridad_promedio
FROM VW_M3_EVALUACIONES
WHERE tipo_objeto = 'Ruta'
GROUP BY cod_estado, cod_municipio, objeto;

CREATE VIEW VW_M3_PLAZOS_INCIDENCIA AS
SELECT nro_reporte, MAX(nueva_fecha_estimada) AS fecha_prorroga, COUNT(*) AS total_prorrogas
FROM Prorroga_Incidencia GROUP BY nro_reporte;

CREATE VIEW VW_M3_OBSERVATORIO AS
SELECT i.*, a.tipo AS tipo_elemento, a.elemento, a.cod_estado, a.cod_municipio,
       r.tipo AS tipo_reportante, r.id_usuario AS usuario_reportante,
       ec.denominacion_oficial AS ente_confirma, ex.denominacion_oficial AS ente_cierra,
       p.fecha_prorroga, COALESCE(p.total_prorrogas, 0) AS total_prorrogas,
       COALESCE(p.fecha_prorroga, i.fecha_estimada_resolucion) AS fecha_limite,
       CASE WHEN i.estado_reporte = 'Activo'
              AND COALESCE(p.fecha_prorroga, i.fecha_estimada_resolucion) <
                  (statement_timestamp() AT TIME ZONE 'America/Caracas')::DATE
            THEN 'Fuera de plazo' ELSE i.estado_reporte END AS estado_efectivo,
       CASE WHEN i.estado_reporte = 'Activo'
              AND p.fecha_prorroga >= (statement_timestamp() AT TIME ZONE 'America/Caracas')::DATE
            THEN TRUE ELSE FALSE END AS prorroga_activa,
       ROUND(EXTRACT(EPOCH FROM (i.fecha_confirmacion - i.fecha_hora_deteccion)) / 3600, 2) AS horas_confirmacion,
       ROUND(EXTRACT(EPOCH FROM (i.fecha_cierre - i.fecha_hora_deteccion)) / 3600, 2) AS horas_cierre
FROM Reporte_Incidencia i
JOIN VW_M3_AFECTABLES a USING (id_elem_afectable)
JOIN VW_M3_REPORTANTES r USING (id_reportante)
LEFT JOIN VW_M3_PLAZOS_INCIDENCIA p USING (nro_reporte)
LEFT JOIN Ente_Publico ec ON ec.id_usuario = i.id_usuario_confirma
LEFT JOIN Ente_Publico ex ON ex.id_usuario = i.id_usuario_cierra;

CREATE VIEW VW_M3_INCIDENCIAS AS
SELECT *
FROM VW_M3_OBSERVATORIO
WHERE current_user IN ('rol_ente_publico', 'rol_admin_rutas', 'rol_reportes')
   OR usuario_reportante = nullif(current_setting('rutas.id_usuario', TRUE), '')::INTEGER
   OR estado_efectivo = 'Activo';

CREATE INDEX IDX_M3_EXPERIENCIA_RUTA_VIGENCIA
    ON Experiencia_Promocional (cod_estado, cod_municipio, nombre_ruta, fecha_activacion, fecha_vencimiento);
CREATE INDEX IDX_M3_EXPERIENCIA_COMERCIO ON Experiencia_Promocional (id_usuario_comercio);
CREATE INDEX IDX_M3_EXPERIENCIA_GUIA ON Experiencia_Promocional (id_usuario_guia);
CREATE INDEX IDX_M3_CREDENCIAL_VISITANTE ON Credencial_Acceso (id_usuario, estado_pase, fecha_hora_visita);
CREATE INDEX IDX_M3_CREDENCIAL_VALIDADOR ON Credencial_Acceso (id_validador, estado_pase, fecha_hora_visita);
CREATE INDEX IDX_M3_EVALUACION_OBJETO ON Evaluacion_Experiencia (id_obj_evaluable, fecha_emision);
CREATE INDEX IDX_M3_INCIDENCIA_ESTADO_SEVERIDAD ON Reporte_Incidencia (estado_reporte, severidad, fecha_hora_deteccion);
CREATE INDEX IDX_M3_INCIDENCIA_ELEMENTO ON Reporte_Incidencia (id_elem_afectable);
CREATE INDEX IDX_M3_INCIDENCIA_REPORTANTE ON Reporte_Incidencia (id_reportante);

COMMIT;
