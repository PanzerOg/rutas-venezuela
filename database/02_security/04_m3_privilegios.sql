-- Módulo 3 · Autor responsable: Leonardo Enrique Chacón Agraz - C.I. 31.895.402
BEGIN;

GRANT SELECT ON VW_M3_AUTH TO rol_m3_autenticacion;
GRANT SELECT ON VW_M3_ACTORES TO rol_admin_rutas;
GRANT SELECT ON VW_M3_EXPERIENCIAS, VW_M3_RUTAS, VW_M3_SERVICIOS, VW_M3_VALIDADORES,
    VW_M3_EVALUABLES, VW_M3_EVALUACIONES, VW_M3_CALIDAD_RUTA, VW_M3_AFECTABLES, VW_M3_INCIDENCIAS,
    Detalle_Experiencia TO rol_visitante, rol_guia, rol_comercio, rol_ente_publico, rol_admin_rutas;
GRANT SELECT ON VW_M3_CREDENCIALES TO rol_visitante, rol_guia, rol_comercio, rol_admin_rutas;
GRANT SELECT ON VW_M3_OBSERVATORIO TO rol_reportes, rol_ente_publico, rol_admin_rutas;
GRANT SELECT ON Prorroga_Incidencia TO rol_ente_publico, rol_admin_rutas;
GRANT SELECT (id_usuario, nro_rtn) ON Guia_Turistico TO rol_comercio;

GRANT SELECT, INSERT, UPDATE, DELETE ON Actor_Usuario, Visitante, Accesibilidad_Visitante,
    Guia_Turistico, Especialidad_Guia, Idioma_Guia, Comercio_Aliado, Horario_Atencion_Comercio,
    Ente_Publico, Tutela, Adscrito_A, Experiencia_Promocional, Detalle_Experiencia,
    Credencial_Acceso, Evaluacion_Experiencia, Reporte_Incidencia, Reportante, Validador_Acceso,
    Elemento_Servicio TO rol_admin_rutas;
GRANT USAGE ON SEQUENCE actor_usuario_id_usuario_seq, reportante_id_reportante_seq,
    validador_acceso_id_validador_seq, elemento_servicio_id_elem_servicio_seq,
    reporte_incidencia_nro_reporte_seq TO rol_admin_rutas;

GRANT SELECT, INSERT, DELETE ON Experiencia_Promocional TO rol_comercio;
GRANT UPDATE (descripcion, precio_total, cupo_maximo, porcentaje_descuento, fecha_vencimiento,
    codigo_promocional, id_usuario_guia, cod_estado, cod_municipio, nombre_ruta)
    ON Experiencia_Promocional TO rol_comercio;
GRANT INSERT, DELETE ON Detalle_Experiencia TO rol_comercio;
GRANT SELECT, INSERT, DELETE ON Evaluacion_Experiencia TO rol_visitante;
GRANT UPDATE (calificacion, indice_seguridad, opinion) ON Evaluacion_Experiencia TO rol_visitante;
GRANT SELECT, DELETE ON Credencial_Acceso TO rol_visitante;
GRANT UPDATE (fecha_hora_visita, monto_abonado, cant_beneficiarios, id_elem_servicio, id_validador)
    ON Credencial_Acceso TO rol_visitante;
GRANT SELECT, DELETE ON Reporte_Incidencia TO rol_visitante, rol_guia;
GRANT UPDATE (descripcion_evento, severidad, fecha_estimada_resolucion, id_elem_afectable)
    ON Reporte_Incidencia TO rol_visitante, rol_guia;

ALTER TABLE Experiencia_Promocional ENABLE ROW LEVEL SECURITY;
CREATE POLICY m3_experiencia_admin ON Experiencia_Promocional TO rol_admin_rutas USING (TRUE);
CREATE POLICY m3_experiencia_comercio ON Experiencia_Promocional TO rol_comercio
    USING (id_usuario_comercio = nullif(current_setting('rutas.id_usuario', TRUE), '')::INTEGER);

ALTER TABLE Detalle_Experiencia ENABLE ROW LEVEL SECURITY;
CREATE POLICY m3_detalle_lectura ON Detalle_Experiencia FOR SELECT USING (TRUE);
CREATE POLICY m3_detalle_admin ON Detalle_Experiencia TO rol_admin_rutas USING (TRUE);
CREATE POLICY m3_detalle_comercio ON Detalle_Experiencia TO rol_comercio
    USING (EXISTS (SELECT 1 FROM Experiencia_Promocional e
        WHERE e.titulo = Detalle_Experiencia.titulo AND e.fecha_activacion = Detalle_Experiencia.fecha_activacion));

ALTER TABLE Evaluacion_Experiencia ENABLE ROW LEVEL SECURITY;
CREATE POLICY m3_evaluacion_admin ON Evaluacion_Experiencia TO rol_admin_rutas USING (TRUE);
CREATE POLICY m3_evaluacion_visitante ON Evaluacion_Experiencia TO rol_visitante
    USING (id_usuario = nullif(current_setting('rutas.id_usuario', TRUE), '')::INTEGER);

ALTER TABLE Credencial_Acceso ENABLE ROW LEVEL SECURITY;
CREATE POLICY m3_credencial_admin ON Credencial_Acceso TO rol_admin_rutas USING (TRUE);
CREATE POLICY m3_credencial_visitante ON Credencial_Acceso TO rol_visitante
    USING (id_usuario = nullif(current_setting('rutas.id_usuario', TRUE), '')::INTEGER AND estado_pase = 'Emitido');

ALTER TABLE Reporte_Incidencia ENABLE ROW LEVEL SECURITY;
CREATE POLICY m3_reporte_admin ON Reporte_Incidencia TO rol_admin_rutas USING (TRUE);
CREATE POLICY m3_reporte_civil ON Reporte_Incidencia TO rol_visitante, rol_guia
    USING (
        estado_reporte = 'Preliminar' AND id_reportante IN (
            SELECT id_reportante FROM VW_M3_REPORTANTES
            WHERE id_usuario = nullif(current_setting('rutas.id_usuario', TRUE), '')::INTEGER
        )
    );
GRANT SELECT ON VW_M3_REPORTANTES TO rol_visitante, rol_guia, rol_admin_rutas;

COMMIT;
