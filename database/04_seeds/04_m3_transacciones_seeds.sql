-- Módulo 3 · Autor responsable: Leonardo Enrique Chacón Agraz - C.I. 31.895.402
BEGIN;

DO $$
DECLARE
    r_hito RECORD;
    r_ruta RECORD;
    v_i INTEGER := 0;
    v_visita TIMESTAMP;
    v_hoy DATE := FN_M3_HORA_LOCAL()::DATE;
    v_anterior TIMESTAMP;
    v_codigo TEXT;
    v_reporte INTEGER;
    v_servicios INTEGER[];
    v_visitantes INTEGER[];
    v_reportantes INTEGER[];
    v_guias INTEGER[];
    v_comercios INTEGER[];
    v_validador INTEGER;
    v_ente INTEGER;
    v_comercio INTEGER;
    v_guia INTEGER;
    v_titulo TEXT;
    v_descripciones TEXT[] := ARRAY['Paso peatonal angosto por obras','Daño en señalización de acceso',
                                     'Interrupción temporal del suministro','Acceso parcialmente obstruido'];
BEGIN
    SELECT array_agg(id_usuario ORDER BY id_usuario), array_agg(id_reportante ORDER BY id_usuario)
    INTO v_visitantes, v_reportantes FROM Visitante
    WHERE doc_identidad LIKE 'V-900000%' OR doc_identidad LIKE 'DEMO-P%';
    SELECT array_agg(id_usuario ORDER BY id_usuario) INTO v_guias FROM Guia_Turistico WHERE nro_rtn LIKE 'RTN-DEMO-%';
    SELECT array_agg(id_usuario ORDER BY id_usuario) INTO v_comercios FROM Comercio_Aliado WHERE rif_comercio LIKE 'J-9900000%';
    SELECT id_validador INTO STRICT v_validador FROM Guia_Turistico WHERE nro_rtn = 'RTN-DEMO-1';
    SELECT array_agg(id_elem_servicio ORDER BY id_elem_servicio) INTO v_servicios FROM VW_M3_SERVICIOS;

    FOR r_hito IN SELECT * FROM Hito_Turistico ORDER BY id_elem_afectable LIMIT 12 LOOP
        v_i := v_i + 1;
        SELECT t.id_usuario INTO STRICT v_ente FROM Tutela t JOIN Ente_Publico e USING (id_usuario)
        WHERE (t.cod_estado,t.cod_municipio,t.cod_parroquia,t.nombre_hito) =
              (r_hito.cod_estado,r_hito.cod_municipio,r_hito.cod_parroquia,r_hito.nombre_hito)
          AND e.rif_institucional IN ('G-99000001-0','G-99000002-0','G-99000003-0','G-99000004-0');
        FOR v_j IN 1..3 LOOP
            INSERT INTO Reporte_Incidencia (fecha_hora_deteccion,fecha_estimada_resolucion,descripcion_evento,
                                           severidad,id_reportante,id_elem_afectable)
            VALUES (FN_M3_HORA_LOCAL()-make_interval(days => v_i),v_hoy+v_j,
                v_descripciones[(v_i+v_j)%4+1], (ARRAY['Bajo','Medio','Critico'])[(v_i+v_j)%3+1],
                v_reportantes[v_i],r_hito.id_elem_afectable) RETURNING nro_reporte INTO v_reporte;
            IF v_j >= 2 THEN
                PERFORM set_config('rutas.id_usuario',v_ente::TEXT,TRUE);
                CALL SP_CONFIRMAR_INCIDENCIA(v_reporte,CASE WHEN v_i%2=0 THEN 'Critico' ELSE 'Medio' END);
                IF v_i%2=0 THEN
                    CALL SP_PRORROGAR_INCIDENCIA(v_reporte,v_hoy+7,'Se necesita una inspección adicional del acceso.');
                END IF;
                IF v_j = 3 THEN
                    CALL SP_CERRAR_INCIDENCIA(v_reporte);
                END IF;
            END IF;
        END LOOP;

        CONTINUE WHEN r_hito.libre_acceso OR r_hito.estado_operativo <> 'Disponible';
        SELECT v_hoy + d.dias + hh.hora_apertura + (hh.hora_cierre-hh.hora_apertura)/2
        INTO v_visita FROM Horario_Hito hh CROSS JOIN generate_series(1,7) AS d(dias)
        WHERE (hh.cod_estado,hh.cod_municipio,hh.cod_parroquia,hh.nombre_hito) =
              (r_hito.cod_estado,r_hito.cod_municipio,r_hito.cod_parroquia,r_hito.nombre_hito)
          AND hh.dia_semana = (ARRAY['Lunes','Martes','Miercoles','Jueves','Viernes','Sabado','Domingo'])
              [EXTRACT(ISODOW FROM v_hoy+d.dias)::INTEGER]
        ORDER BY d.dias,hh.hora_apertura LIMIT 1;
        SELECT v_hoy - d.dias + hh.hora_apertura + (hh.hora_cierre-hh.hora_apertura)/2
        INTO v_anterior FROM Horario_Hito hh CROSS JOIN generate_series(1,7) AS d(dias)
        WHERE (hh.cod_estado,hh.cod_municipio,hh.cod_parroquia,hh.nombre_hito) =
              (r_hito.cod_estado,r_hito.cod_municipio,r_hito.cod_parroquia,r_hito.nombre_hito)
          AND hh.dia_semana = (ARRAY['Lunes','Martes','Miercoles','Jueves','Viernes','Sabado','Domingo'])
              [EXTRACT(ISODOW FROM v_hoy-d.dias)::INTEGER]
        ORDER BY d.dias,hh.hora_apertura LIMIT 1;
        CONTINUE WHEN v_visita IS NULL OR v_anterior IS NULL;

        FOR v_j IN 1..4 LOOP
            v_codigo := 'M3DEMO' || lpad(v_i::TEXT,2,'0') || v_j;
            INSERT INTO Credencial_Acceso (cod_verificacion,fecha_hora_visita,monto_abonado,cant_beneficiarios,
                                           id_usuario,id_elem_servicio,id_validador)
            VALUES (v_codigo,CASE WHEN v_j%2=0 THEN v_anterior ELSE v_visita END,3+v_i,1+v_i%3,
                    v_visitantes[v_i],r_hito.id_elem_servicio,v_validador);
            CASE v_j
                WHEN 2 THEN UPDATE Credencial_Acceso SET estado_pase='Canjeado',fecha_hora_canje=v_anterior
                            WHERE cod_verificacion=v_codigo;
                WHEN 3 THEN UPDATE Credencial_Acceso SET estado_pase='Cancelado' WHERE cod_verificacion=v_codigo;
                WHEN 4 THEN UPDATE Credencial_Acceso SET estado_pase='Vencido' WHERE cod_verificacion=v_codigo;
                ELSE NULL;
            END CASE;
        END LOOP;
        INSERT INTO Evaluacion_Experiencia (cod_resena,calificacion,indice_seguridad,opinion,id_usuario,id_obj_evaluable)
        VALUES ('M3RES' || v_i,4+v_i%2,3+v_i%3,'El personal nos orientó para apreciar la historia del lugar.',
                v_visitantes[v_i],r_hito.id_obj_evaluable);
    END LOOP;

    v_i := 0;
    FOR r_ruta IN SELECT * FROM VW_M3_RUTAS ORDER BY cod_estado,cod_municipio,nombre_ruta LIMIT 12 LOOP
        v_i := v_i + 1;
        v_guia := v_guias[(v_i-1)%cardinality(v_guias)+1];
        v_comercio := v_comercios[(v_i-1)%cardinality(v_comercios)+1];
        INSERT INTO Adscrito_A VALUES (r_ruta.cod_estado,r_ruta.cod_municipio,r_ruta.nombre_ruta,v_guia)
            ON CONFLICT DO NOTHING;
        IF cardinality(v_servicios) >= 2 THEN
            FOR v_j IN 1..2 LOOP
                v_titulo := CASE WHEN v_j=1 THEN 'Jornada patrimonial ' ELSE 'Paseo con guía ' END || v_i;
                INSERT INTO Experiencia_Promocional VALUES (v_titulo,v_hoy-v_j,
                    'Recorrido interpretativo por ' || r_ruta.nombre_ruta,25+v_i,10+v_i,10,
                    v_hoy+v_j*7,'M3PROMO' || v_i || 'X' || v_j,v_comercio,v_guia,
                    r_ruta.cod_estado,r_ruta.cod_municipio,r_ruta.nombre_ruta);
                INSERT INTO Detalle_Experiencia VALUES (v_titulo,v_hoy-v_j,1,15,v_servicios[1]),
                                                        (v_titulo,v_hoy-v_j,2,20,v_servicios[2]);
            END LOOP;
        END IF;
    END LOOP;

    IF to_regclass('public.historial_recorrido') IS NOT NULL THEN
        INSERT INTO Evaluacion_Experiencia (cod_resena,calificacion,indice_seguridad,opinion,id_usuario,id_obj_evaluable)
        SELECT 'M3RUTA' || h.id_recorrido, 5, 4, 'Recorrido con buena orientación y paradas útiles.',
               h.id_usuario, r.id_obj_evaluable
        FROM Historial_Recorrido h JOIN VW_M3_RUTAS r USING (cod_estado,cod_municipio,nombre_ruta)
        WHERE h.completado AND COALESCE(h.fecha_hora_fin,h.fecha_hora_inicio) <= FN_M3_HORA_LOCAL()
        ORDER BY h.id_recorrido LIMIT 12;
    END IF;
END;
$$;

COMMIT;
