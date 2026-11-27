-- Módulo 3 · Autor responsable: Leonardo Enrique Chacón Agraz - C.I. 31.895.402
BEGIN;

-- RR-M3-01 y RR-M3-13. Se revisa el estado final de la transacción.
CREATE OR REPLACE FUNCTION FN_M3_PERFIL_ACTOR(p_id INTEGER) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
    v_tipo TEXT;
    v_perfiles TEXT[];
BEGIN
    SELECT tipo_actor INTO v_tipo FROM Actor_Usuario WHERE id_usuario = p_id FOR NO KEY UPDATE;
    IF NOT FOUND THEN
        RETURN;
    END IF;
    v_perfiles := array_remove(ARRAY[
        CASE WHEN EXISTS (SELECT 1 FROM Visitante WHERE id_usuario = p_id) THEN 'Visitante' END,
        CASE WHEN EXISTS (SELECT 1 FROM Guia_Turistico WHERE id_usuario = p_id) THEN 'Guia' END,
        CASE WHEN EXISTS (SELECT 1 FROM Comercio_Aliado WHERE id_usuario = p_id) THEN 'Comercio' END,
        CASE WHEN EXISTS (SELECT 1 FROM Ente_Publico WHERE id_usuario = p_id) THEN 'Ente' END
    ], NULL);
    IF v_perfiles IS DISTINCT FROM ARRAY[v_tipo] THEN
        RAISE EXCEPTION 'El actor % debe tener un único perfil de tipo %.', p_id, v_tipo USING ERRCODE = '23514';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION FN_M3_EXCLUSIVIDAD_ACTOR() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN
        PERFORM FN_M3_PERFIL_ACTOR(OLD.id_usuario);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        PERFORM FN_M3_PERFIL_ACTOR(NEW.id_usuario);
    END IF;
    RETURN NULL;
END;
$$;

DO $$
DECLARE
    v_tabla TEXT;
BEGIN
    FOREACH v_tabla IN ARRAY ARRAY['actor_usuario','visitante','guia_turistico','comercio_aliado','ente_publico'] LOOP
        EXECUTE format('CREATE CONSTRAINT TRIGGER TG_EXCLUSIVIDAD_ACTOR
            AFTER INSERT OR UPDATE OF id_usuario%s OR DELETE ON %I
            DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION FN_M3_EXCLUSIVIDAD_ACTOR()',
            CASE WHEN v_tabla = 'actor_usuario' THEN ', tipo_actor' ELSE '' END, v_tabla);
    END LOOP;
END;
$$;

-- Serializa la reasignación de una categoría, incluso con escrituras simultáneas
-- desde distintas superclases. El UPDATE materializa el conflicto en MVCC.
CREATE OR REPLACE FUNCTION FN_M3_BLOQUEAR_CATEGORIA() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
    v_anterior INTEGER;
    v_nuevo INTEGER;
    v_id INTEGER;
BEGIN
    IF TG_OP <> 'INSERT' THEN
        v_anterior := (to_jsonb(OLD) ->> TG_ARGV[1])::INTEGER;
    END IF;
    IF TG_OP <> 'DELETE' THEN
        v_nuevo := (to_jsonb(NEW) ->> TG_ARGV[1])::INTEGER;
    END IF;
    IF v_anterior IS DISTINCT FROM v_nuevo THEN
        FOR v_id IN SELECT DISTINCT unnest(ARRAY[v_anterior, v_nuevo]) ORDER BY 1 LOOP
            CONTINUE WHEN v_id IS NULL;
            EXECUTE format('UPDATE %1$I SET %2$I = %2$I WHERE %2$I = $1', TG_ARGV[0], TG_ARGV[1]) USING v_id;
        END LOOP;
    END IF;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

CREATE OR REPLACE FUNCTION FN_M3_MIEMBROS_CATEGORIA(p_id INTEGER, p_tabla TEXT, p_clave TEXT, p_miembros TEXT[])
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
    v_existe BOOLEAN;
    v_miembro TEXT;
    v_total INTEGER := 0;
    v_cantidad INTEGER;
BEGIN
    EXECUTE format('SELECT TRUE FROM %I WHERE %I = $1', p_tabla, p_clave) INTO v_existe USING p_id;
    IF v_existe IS DISTINCT FROM TRUE THEN
        RETURN;
    END IF;
    FOREACH v_miembro IN ARRAY p_miembros LOOP
        IF to_regclass('public.' || v_miembro) IS NOT NULL THEN
            EXECUTE format('SELECT count(*) FROM %I WHERE %I = $1', v_miembro, p_clave) INTO v_cantidad USING p_id;
            v_total := v_total + v_cantidad;
        END IF;
    END LOOP;
    IF v_total <> 1 THEN
        RAISE EXCEPTION 'La categoría % (%) debe tener exactamente un miembro. Encontrados: %.',
            p_tabla, p_id, v_total USING ERRCODE = '23514';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION FN_M3_EXCLUSIVIDAD_CATEGORIA() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
    v_anterior INTEGER;
    v_nuevo INTEGER;
    v_miembros TEXT[] := string_to_array(TG_ARGV[2], ',');
BEGIN
    IF TG_OP <> 'INSERT' THEN
        v_anterior := (to_jsonb(OLD) ->> TG_ARGV[1])::INTEGER;
    END IF;
    IF TG_OP <> 'DELETE' THEN
        v_nuevo := (to_jsonb(NEW) ->> TG_ARGV[1])::INTEGER;
    END IF;
    IF v_anterior IS DISTINCT FROM v_nuevo THEN
        PERFORM FN_M3_MIEMBROS_CATEGORIA(v_anterior, TG_ARGV[0], TG_ARGV[1], v_miembros);
        PERFORM FN_M3_MIEMBROS_CATEGORIA(v_nuevo, TG_ARGV[0], TG_ARGV[1], v_miembros);
    END IF;
    RETURN NULL;
END;
$$;

DO $$
DECLARE
    v_def TEXT[];
    v_tabla TEXT;
    v_trigger TEXT;
BEGIN
    FOREACH v_def SLICE 1 IN ARRAY ARRAY[
        ['punto_itinerario', 'id_punto_itin', 'hito_turistico,parada_transporte'],
        ['elemento_afectable', 'id_elem_afectable', 'hito_turistico,tramo_via'],
        ['objeto_evaluable', 'id_obj_evaluable', 'hito_turistico,ruta'],
        ['elemento_servicio', 'id_elem_servicio', 'hito_turistico,comercio_aliado'],
        ['validador_acceso', 'id_validador', 'guia_turistico,comercio_aliado'],
        ['reportante', 'id_reportante', 'visitante,guia_turistico,ente_publico']
    ] LOOP
        FOREACH v_tabla IN ARRAY array_prepend(v_def[1], string_to_array(v_def[3], ',')) LOOP
            CONTINUE WHEN to_regclass('public.' || v_tabla) IS NULL;
            v_trigger := 'tg_exclusividad_categoria_' || v_def[1];
            EXECUTE format('CREATE CONSTRAINT TRIGGER %I
                AFTER INSERT OR UPDATE OF %I OR DELETE ON %I DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
                EXECUTE FUNCTION FN_M3_EXCLUSIVIDAD_CATEGORIA(%L, %L, %L)',
                v_trigger, v_def[2], v_tabla, v_def[1], v_def[2], v_def[3]);
            IF v_tabla <> v_def[1] THEN
                EXECUTE format('CREATE TRIGGER %I BEFORE INSERT OR UPDATE OF %I OR DELETE ON %I FOR EACH ROW
                    EXECUTE FUNCTION FN_M3_BLOQUEAR_CATEGORIA(%L, %L)',
                    'tg_bloquear_categoria_' || v_def[1], v_def[2], v_tabla, v_def[1], v_def[2]);
            END IF;
        END LOOP;
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION FN_M3_PERFIL_RUTA(p_estado TEXT, p_municipio TEXT, p_ruta TEXT) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
    v_tipo TEXT;
BEGIN
    SELECT tipo_ruta INTO v_tipo FROM Ruta
    WHERE (cod_estado, cod_municipio, nombre_ruta) = (p_estado, p_municipio, p_ruta) FOR NO KEY UPDATE;
    IF NOT FOUND THEN
        RETURN;
    END IF;
    IF (v_tipo = 'Fija') IS DISTINCT FROM EXISTS (
        SELECT 1 FROM Ruta_Fija WHERE (cod_estado, cod_municipio, nombre_ruta) = (p_estado, p_municipio, p_ruta)
    ) OR (v_tipo = 'Dinamica') IS DISTINCT FROM EXISTS (
        SELECT 1 FROM Ruta_Dinamica WHERE (cod_estado, cod_municipio, nombre_ruta) = (p_estado, p_municipio, p_ruta)
    ) THEN
        RAISE EXCEPTION 'La ruta % debe tener un único perfil de tipo %.', p_ruta, v_tipo USING ERRCODE = '23514';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION FN_M3_EXCLUSIVIDAD_RUTA() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN
        PERFORM FN_M3_PERFIL_RUTA(OLD.cod_estado, OLD.cod_municipio, OLD.nombre_ruta);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        PERFORM FN_M3_PERFIL_RUTA(NEW.cod_estado, NEW.cod_municipio, NEW.nombre_ruta);
    END IF;
    RETURN NULL;
END;
$$;

DO $$
DECLARE
    v_tabla TEXT;
BEGIN
    IF to_regclass('public.ruta_fija') IS NOT NULL AND to_regclass('public.ruta_dinamica') IS NOT NULL THEN
        FOREACH v_tabla IN ARRAY ARRAY['ruta','ruta_fija','ruta_dinamica'] LOOP
            EXECUTE format('CREATE CONSTRAINT TRIGGER TG_M3_EXCLUSIVIDAD_RUTA
                AFTER INSERT OR UPDATE OF cod_estado, cod_municipio, nombre_ruta%s OR DELETE ON %I
                DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION FN_M3_EXCLUSIVIDAD_RUTA()',
                CASE WHEN v_tabla = 'ruta' THEN ', tipo_ruta' ELSE '' END, v_tabla);
        END LOOP;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION FN_M3_EXPERIENCIA_CON_DETALLE() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
    v_titulo TEXT;
    v_fecha DATE;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_titulo := NEW.titulo;
        v_fecha := NEW.fecha_activacion;
    ELSE
        v_titulo := OLD.titulo;
        v_fecha := OLD.fecha_activacion;
    END IF;
    PERFORM 1 FROM Experiencia_Promocional WHERE titulo = v_titulo AND fecha_activacion = v_fecha FOR NO KEY UPDATE;
    IF FOUND AND NOT EXISTS (
        SELECT 1 FROM Detalle_Experiencia WHERE titulo = v_titulo AND fecha_activacion = v_fecha
    ) THEN
        RAISE EXCEPTION 'La experiencia % debe incluir al menos un servicio.', v_titulo USING ERRCODE = '23514';
    END IF;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION FN_M3_BLOQUEAR_EXPERIENCIA() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
BEGIN
    UPDATE Experiencia_Promocional SET descripcion = descripcion
    WHERE titulo = OLD.titulo AND fecha_activacion = OLD.fecha_activacion;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

CREATE CONSTRAINT TRIGGER TG_VALIDAR_DETALLE_EXPERIENCIA AFTER INSERT ON Experiencia_Promocional
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION FN_M3_EXPERIENCIA_CON_DETALLE();
CREATE TRIGGER TG_BLOQUEAR_DETALLE_EXPERIENCIA BEFORE DELETE OR UPDATE OF titulo, fecha_activacion ON Detalle_Experiencia
    FOR EACH ROW EXECUTE FUNCTION FN_M3_BLOQUEAR_EXPERIENCIA();
CREATE CONSTRAINT TRIGGER TG_VALIDAR_DETALLE_EXPERIENCIA AFTER DELETE OR UPDATE OF titulo, fecha_activacion
    ON Detalle_Experiencia DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION FN_M3_EXPERIENCIA_CON_DETALLE();

CREATE OR REPLACE FUNCTION FN_M3_HORA_LOCAL() RETURNS TIMESTAMP
LANGUAGE sql VOLATILE SET search_path = pg_catalog, public AS $$
    SELECT clock_timestamp() AT TIME ZONE 'America/Caracas';
$$;

CREATE OR REPLACE FUNCTION FN_M3_USUARIO_ACTUAL() RETURNS INTEGER
LANGUAGE sql STABLE SET search_path = pg_catalog, public AS $$
    SELECT nullif(current_setting('rutas.id_usuario', TRUE), '')::INTEGER;
$$;

-- RN-M3-03 y RR-M3-12. El día y la hora son los de Caracas.
CREATE OR REPLACE FUNCTION FN_M3_HORARIO_SERVICIO(p_servicio INTEGER, p_fecha TIMESTAMP) RETURNS BOOLEAN
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
    v_dia TEXT := (ARRAY['Lunes','Martes','Miercoles','Jueves','Viernes','Sabado','Domingo'])
        [EXTRACT(ISODOW FROM p_fecha)::INTEGER];
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM Hito_Turistico h JOIN Horario_Hito hh
            USING (cod_estado, cod_municipio, cod_parroquia, nombre_hito)
        WHERE h.id_elem_servicio = p_servicio AND h.estado_operativo = 'Disponible'
          AND NOT h.libre_acceso AND hh.dia_semana = v_dia
          AND p_fecha::TIME >= hh.hora_apertura AND p_fecha::TIME < hh.hora_cierre
    ) OR EXISTS (
        SELECT 1 FROM Comercio_Aliado c JOIN Horario_Atencion_Comercio hc USING (id_usuario)
        WHERE c.id_elem_servicio = p_servicio AND hc.dia = v_dia
          AND p_fecha::TIME >= hc.apertura AND p_fecha::TIME < hc.cierre
    );
END;
$$;

CREATE OR REPLACE FUNCTION FN_M3_VALIDAR_CREDENCIAL() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        IF OLD.estado_pase <> 'Emitido' OR OLD.fecha_hora_visita < FN_M3_HORA_LOCAL() THEN
            RAISE EXCEPTION 'La credencial se conserva para auditoría al quedar fuera de vigencia.' USING ERRCODE = '23514';
        END IF;
        RETURN OLD;
    END IF;
    IF TG_OP = 'INSERT' AND NEW.estado_pase <> 'Emitido' THEN
        RAISE EXCEPTION 'Una credencial nueva debe comenzar como Emitido.' USING ERRCODE = '23514';
    END IF;
    IF TG_OP = 'UPDATE' THEN
        IF OLD.estado_pase <> 'Emitido' AND NEW IS DISTINCT FROM OLD THEN
            RAISE EXCEPTION 'La credencial ya alcanzó un estado final.' USING ERRCODE = '23514';
        END IF;
        IF NEW.cod_verificacion IS DISTINCT FROM OLD.cod_verificacion THEN
            RAISE EXCEPTION 'El código de una credencial es inmutable.' USING ERRCODE = '23514';
        END IF;
        IF NEW.estado_pase = 'Vencido' AND OLD.estado_pase = 'Emitido'
           AND NEW.fecha_hora_visita >= FN_M3_HORA_LOCAL() THEN
            RAISE EXCEPTION 'La fecha de visita de esta credencial aún no ha pasado.' USING ERRCODE = '23514';
        END IF;
        IF NEW.estado_pase = 'Canjeado' AND OLD.estado_pase = 'Emitido' THEN
            IF NEW.fecha_hora_canje > FN_M3_HORA_LOCAL()
               OR NOT FN_M3_HORARIO_SERVICIO(NEW.id_elem_servicio, NEW.fecha_hora_canje) THEN
                RAISE EXCEPTION 'El canje debe realizarse en el horario autorizado.' USING ERRCODE = '23514';
            END IF;
            RETURN NEW;
        END IF;
        IF OLD.estado_pase <> 'Emitido' OR NEW.estado_pase <> 'Emitido' THEN
            RETURN NEW;
        END IF;
        IF OLD.fecha_hora_visita < FN_M3_HORA_LOCAL() AND NEW IS DISTINCT FROM OLD THEN
            RAISE EXCEPTION 'Una credencial vencida ya no admite cambios de reserva.' USING ERRCODE = '23514';
        END IF;
    END IF;
    IF NOT FN_M3_HORARIO_SERVICIO(NEW.id_elem_servicio, NEW.fecha_hora_visita) THEN
        RAISE EXCEPTION 'El servicio requiere reserva y debe operar a la hora elegida.' USING ERRCODE = '23514';
    END IF;
    IF EXISTS (
        SELECT 1 FROM Comercio_Aliado
        WHERE id_elem_servicio = NEW.id_elem_servicio AND aforo < NEW.cant_beneficiarios
    ) THEN
        RAISE EXCEPTION 'La cantidad de beneficiarios supera el aforo del comercio.' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER TG_VALIDAR_CANJE_CREDENCIAL BEFORE INSERT OR UPDATE OR DELETE ON Credencial_Acceso
    FOR EACH ROW EXECUTE FUNCTION FN_M3_VALIDAR_CREDENCIAL();

CREATE OR REPLACE FUNCTION FN_M3_EMITIR_CREDENCIAL(
    p_codigo TEXT, p_visita TIMESTAMP, p_monto NUMERIC, p_cantidad INTEGER, p_servicio INTEGER, p_validador INTEGER
) RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
BEGIN
    IF p_visita <= FN_M3_HORA_LOCAL() THEN
        RAISE EXCEPTION 'La fecha programada debe estar en el futuro.' USING ERRCODE = '23514';
    END IF;
    INSERT INTO Credencial_Acceso (cod_verificacion, fecha_hora_visita, monto_abonado, cant_beneficiarios,
                                  id_usuario, id_elem_servicio, id_validador)
    VALUES (p_codigo, p_visita, p_monto, p_cantidad, FN_M3_USUARIO_ACTUAL(), p_servicio, p_validador);
    RETURN p_codigo;
END;
$$;

CREATE OR REPLACE PROCEDURE SP_CANJEAR_CREDENCIAL(p_codigo TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
    v_ahora TIMESTAMP;
BEGIN
    PERFORM 1 FROM Credencial_Acceso c JOIN VW_M3_VALIDADORES v USING (id_validador)
    WHERE c.cod_verificacion = p_codigo AND c.id_validador = v.id_validador
      AND v.id_usuario = FN_M3_USUARIO_ACTUAL() AND c.estado_pase = 'Emitido'
    FOR UPDATE OF c;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Credencial no disponible para canje con este validador en este momento.' USING ERRCODE = '23514';
    END IF;
    v_ahora := FN_M3_HORA_LOCAL();
    UPDATE Credencial_Acceso SET estado_pase = 'Canjeado', fecha_hora_canje = v_ahora
    WHERE cod_verificacion = p_codigo
      AND fecha_hora_visita::DATE = v_ahora::DATE AND fecha_hora_visita >= v_ahora;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Credencial no disponible para canje con este validador en este momento.' USING ERRCODE = '23514';
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE SP_M3_ESTADO_CREDENCIAL(p_codigo TEXT, p_estado TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
BEGIN
    IF p_estado IS NULL OR p_estado NOT IN ('Cancelado', 'Vencido') THEN
        RAISE EXCEPTION 'Seleccione Cancelado o Vencido.' USING ERRCODE = '23514';
    END IF;
    UPDATE Credencial_Acceso SET estado_pase = p_estado
    WHERE cod_verificacion = p_codigo AND estado_pase = 'Emitido'
      AND (id_usuario = FN_M3_USUARIO_ACTUAL() OR current_setting('role') = 'rol_admin_rutas')
      AND (p_estado <> 'Cancelado' OR fecha_hora_visita >= FN_M3_HORA_LOCAL());
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Credencial no disponible para el cambio solicitado.' USING ERRCODE = '23514';
    END IF;
END;
$$;

-- Una ruta exige un historial completado. Un hito admite un paso registrado
-- o el canje previo de una credencial del mismo visitante y servicio.
CREATE OR REPLACE FUNCTION FN_M3_VALIDAR_EVALUACION() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
    v_valida BOOLEAN := FALSE;
BEGIN
    IF TG_OP = 'UPDATE' AND (NEW.id_usuario, NEW.id_obj_evaluable, NEW.fecha_emision) IS NOT DISTINCT FROM
                           (OLD.id_usuario, OLD.id_obj_evaluable, OLD.fecha_emision) THEN
        RETURN NEW;
    END IF;
    IF NEW.fecha_emision > FN_M3_HORA_LOCAL() THEN
        RAISE EXCEPTION 'La fecha de emisión no puede estar en el futuro.' USING ERRCODE = '23514';
    END IF;
    IF to_regclass('public.historial_recorrido') IS NOT NULL AND to_regclass('public.ruta') IS NOT NULL THEN
        v_valida := EXISTS (
            SELECT 1 FROM Historial_Recorrido h JOIN Ruta r USING (cod_estado, cod_municipio, nombre_ruta)
            WHERE h.id_usuario = NEW.id_usuario AND r.id_obj_evaluable = NEW.id_obj_evaluable
              AND h.completado AND COALESCE(h.fecha_hora_fin, h.fecha_hora_inicio) <= NEW.fecha_emision
        );
        IF NOT v_valida AND to_regclass('public.historial_paso') IS NOT NULL THEN
            v_valida := EXISTS (
                SELECT 1 FROM Historial_Paso p JOIN Historial_Recorrido h USING (id_recorrido)
                JOIN Hito_Turistico t USING (id_punto_itin)
                WHERE h.id_usuario = NEW.id_usuario AND t.id_obj_evaluable = NEW.id_obj_evaluable
                  AND p.fecha_hora_llegada <= NEW.fecha_emision
            );
        END IF;
    END IF;
    IF NOT v_valida AND NOT EXISTS (
        SELECT 1 FROM Credencial_Acceso c JOIN Hito_Turistico h USING (id_elem_servicio)
        WHERE c.id_usuario = NEW.id_usuario AND h.id_obj_evaluable = NEW.id_obj_evaluable
          AND c.estado_pase = 'Canjeado' AND c.fecha_hora_canje <= NEW.fecha_emision
    ) THEN
        RAISE EXCEPTION 'No hay constancia previa de que el visitante completó la ruta o visitó el hito.'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER TG_VERIFICAR_EVALUACION BEFORE INSERT OR UPDATE ON Evaluacion_Experiencia
    FOR EACH ROW EXECUTE FUNCTION FN_M3_VALIDAR_EVALUACION();

CREATE OR REPLACE FUNCTION FN_M3_COMPETENCIA_INCIDENCIA(p_ente INTEGER, p_elemento INTEGER) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public AS $$
    SELECT NOT EXISTS (
        SELECT 1 FROM Hito_Turistico h JOIN Tutela t USING (cod_estado, cod_municipio, cod_parroquia, nombre_hito)
        WHERE h.id_elem_afectable = p_elemento
    ) OR EXISTS (
        SELECT 1 FROM Hito_Turistico h JOIN Tutela t USING (cod_estado, cod_municipio, cod_parroquia, nombre_hito)
        WHERE h.id_elem_afectable = p_elemento AND t.id_usuario = p_ente
    );
$$;

CREATE OR REPLACE FUNCTION FN_M3_VALIDAR_INCIDENCIA() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
    v_ente INTEGER;
BEGIN
    IF TG_OP = 'DELETE' THEN
        IF OLD.estado_reporte <> 'Preliminar' THEN
            RAISE EXCEPTION 'Una incidencia confirmada se conserva para auditoría.' USING ERRCODE = '23514';
        END IF;
        RETURN OLD;
    END IF;
    IF NEW.fecha_hora_deteccion > FN_M3_HORA_LOCAL() THEN
        RAISE EXCEPTION 'La detección no puede estar en el futuro.' USING ERRCODE = '23514';
    END IF;
    IF TG_OP = 'INSERT' THEN
        SELECT id_usuario INTO v_ente FROM Ente_Publico WHERE id_reportante = NEW.id_reportante;
        IF NEW.estado_reporte <> 'Preliminar' OR
           num_nonnulls(NEW.id_usuario_confirma, NEW.fecha_confirmacion, NEW.id_usuario_cierra, NEW.fecha_cierre) <> 0 THEN
            RAISE EXCEPTION 'El estado inicial se asigna según el tipo de reportante.' USING ERRCODE = '23514';
        END IF;
        IF v_ente IS NOT NULL THEN
            NEW.estado_reporte := 'Activo';
            NEW.id_usuario_confirma := v_ente;
            NEW.fecha_confirmacion := FN_M3_HORA_LOCAL();
        END IF;
    ELSE
        IF (NEW.nro_reporte, NEW.id_reportante, NEW.fecha_hora_deteccion) IS DISTINCT FROM
           (OLD.nro_reporte, OLD.id_reportante, OLD.fecha_hora_deteccion) THEN
            RAISE EXCEPTION 'El número, reportante y fecha de detección son inmutables.' USING ERRCODE = '23514';
        END IF;
        IF OLD.estado_reporte = 'Resuelto' AND NEW IS DISTINCT FROM OLD THEN
            RAISE EXCEPTION 'Una incidencia resuelta se conserva para auditoría.' USING ERRCODE = '23514';
        END IF;
        IF OLD.estado_reporte = 'Activo' AND (
            NEW.estado_reporte NOT IN ('Activo','Resuelto') OR
            (NEW.id_usuario_confirma, NEW.fecha_confirmacion, NEW.fecha_estimada_resolucion,
             NEW.id_elem_afectable, NEW.severidad, NEW.descripcion_evento) IS DISTINCT FROM
            (OLD.id_usuario_confirma, OLD.fecha_confirmacion, OLD.fecha_estimada_resolucion,
             OLD.id_elem_afectable, OLD.severidad, OLD.descripcion_evento)
        ) THEN
            RAISE EXCEPTION 'El reporte activo solo admite prórrogas justificadas o cierre formal.' USING ERRCODE = '23514';
        END IF;
        IF OLD.estado_reporte = 'Preliminar' AND NEW.estado_reporte = 'Resuelto' THEN
            RAISE EXCEPTION 'Confirme la incidencia antes de cerrarla.' USING ERRCODE = '23514';
        END IF;
        IF NEW.estado_reporte = 'Resuelto' AND NEW.id_usuario_cierra <> OLD.id_usuario_confirma THEN
            RAISE EXCEPTION 'Solo el ente que confirmó la incidencia puede cerrarla.' USING ERRCODE = '23514';
        END IF;
    END IF;
    IF NEW.estado_reporte = 'Activo' AND (TG_OP = 'INSERT' OR OLD.estado_reporte = 'Preliminar') THEN
        IF NEW.fecha_estimada_resolucion < FN_M3_HORA_LOCAL()::DATE THEN
            RAISE EXCEPTION 'La fecha estimada debe estar vigente al confirmar la incidencia.' USING ERRCODE = '23514';
        END IF;
        IF NOT FN_M3_COMPETENCIA_INCIDENCIA(NEW.id_usuario_confirma, NEW.id_elem_afectable) THEN
            RAISE EXCEPTION 'El ente no tiene tutela sobre el hito afectado.' USING ERRCODE = '23514';
        END IF;
    END IF;
    IF NEW.fecha_confirmacion > FN_M3_HORA_LOCAL() OR NEW.fecha_cierre > FN_M3_HORA_LOCAL() THEN
        RAISE EXCEPTION 'La confirmación y el cierre deben registrar un hecho ocurrido.' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER TG_VALIDAR_ESTADO_INCIDENCIA BEFORE INSERT OR UPDATE OR DELETE ON Reporte_Incidencia
    FOR EACH ROW EXECUTE FUNCTION FN_M3_VALIDAR_INCIDENCIA();

CREATE OR REPLACE FUNCTION FN_M3_VALIDAR_PRORROGA() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
    v_estado TEXT;
    v_limite DATE;
BEGIN
    IF TG_OP <> 'INSERT' THEN
        RAISE EXCEPTION 'Una prórroga registrada se conserva para auditoría.' USING ERRCODE = '23514';
    END IF;
    UPDATE Reporte_Incidencia SET severidad = severidad
    WHERE nro_reporte = NEW.nro_reporte
    RETURNING estado_reporte, fecha_estimada_resolucion INTO v_estado, v_limite;
    IF v_estado IS DISTINCT FROM 'Activo' THEN
        RAISE EXCEPTION 'Solo se puede prorrogar una incidencia confirmada pendiente de cierre.' USING ERRCODE = '23514';
    END IF;
    SELECT GREATEST(v_limite, MAX(nueva_fecha_estimada)) INTO v_limite
    FROM Prorroga_Incidencia WHERE nro_reporte = NEW.nro_reporte;
    IF NEW.nueva_fecha_estimada <= GREATEST(v_limite, FN_M3_HORA_LOCAL()::DATE) THEN
        RAISE EXCEPTION 'La prórroga debe superar la fecha límite actual y la fecha de hoy.' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER TG_VALIDAR_PRORROGA_INCIDENCIA BEFORE INSERT OR UPDATE OR DELETE ON Prorroga_Incidencia
    FOR EACH ROW EXECUTE FUNCTION FN_M3_VALIDAR_PRORROGA();

CREATE OR REPLACE FUNCTION FN_M3_REPORTAR_INCIDENCIA(
    p_deteccion TIMESTAMP, p_estimada DATE, p_descripcion TEXT, p_severidad TEXT, p_elemento INTEGER
) RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
    v_reportante INTEGER;
    v_id INTEGER;
BEGIN
    SELECT id_reportante INTO STRICT v_reportante FROM VW_M3_REPORTANTES WHERE id_usuario = FN_M3_USUARIO_ACTUAL();
    INSERT INTO Reporte_Incidencia (fecha_hora_deteccion, fecha_estimada_resolucion, descripcion_evento,
                                   severidad, id_reportante, id_elem_afectable)
    VALUES (p_deteccion, p_estimada, p_descripcion, p_severidad, v_reportante, p_elemento)
    RETURNING nro_reporte INTO v_id;
    RETURN v_id;
END;
$$;

CREATE OR REPLACE PROCEDURE SP_CONFIRMAR_INCIDENCIA(p_nro INTEGER, p_severidad TEXT, p_nueva_estimada DATE DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
BEGIN
    UPDATE Reporte_Incidencia SET estado_reporte = 'Activo', severidad = p_severidad,
        id_usuario_confirma = FN_M3_USUARIO_ACTUAL(), fecha_confirmacion = FN_M3_HORA_LOCAL(),
        fecha_estimada_resolucion = COALESCE(p_nueva_estimada, fecha_estimada_resolucion)
    WHERE nro_reporte = p_nro AND estado_reporte = 'Preliminar'
      AND EXISTS (SELECT 1 FROM Ente_Publico WHERE id_usuario = FN_M3_USUARIO_ACTUAL());
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El reporte no está disponible para confirmación.' USING ERRCODE = '23514';
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE SP_PRORROGAR_INCIDENCIA(p_nro INTEGER, p_nueva DATE, p_justificacion TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
    v_numero INTEGER;
BEGIN
    PERFORM 1 FROM Reporte_Incidencia
    WHERE nro_reporte = p_nro AND estado_reporte = 'Activo' AND id_usuario_confirma = FN_M3_USUARIO_ACTUAL()
    FOR NO KEY UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Solo el ente que confirmó puede prorrogar una incidencia pendiente de cierre.' USING ERRCODE = '23514';
    END IF;
    SELECT COALESCE(MAX(nro_prorroga), 0) + 1 INTO v_numero FROM Prorroga_Incidencia WHERE nro_reporte = p_nro;
    INSERT INTO Prorroga_Incidencia (nro_reporte, nro_prorroga, nueva_fecha_estimada, justificacion)
    VALUES (p_nro, v_numero, p_nueva, p_justificacion);
END;
$$;

CREATE OR REPLACE PROCEDURE SP_CERRAR_INCIDENCIA(p_nro INTEGER)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
BEGIN
    UPDATE Reporte_Incidencia SET estado_reporte = 'Resuelto',
        id_usuario_cierra = FN_M3_USUARIO_ACTUAL(), fecha_cierre = FN_M3_HORA_LOCAL()
    WHERE nro_reporte = p_nro AND estado_reporte = 'Activo' AND id_usuario_confirma = FN_M3_USUARIO_ACTUAL();
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Solo el ente que confirmó puede cerrar la incidencia.' USING ERRCODE = '23514';
    END IF;
END;
$$;

CREATE VIEW VW_M3_BANDEJA_INSTITUCIONAL AS
SELECT * FROM VW_M3_OBSERVATORIO i
WHERE i.estado_reporte = 'Preliminar'
  AND FN_M3_COMPETENCIA_INCIDENCIA(FN_M3_USUARIO_ACTUAL(), i.id_elem_afectable);

REVOKE EXECUTE ON FUNCTION FN_M3_PERFIL_ACTOR(INTEGER), FN_M3_EXCLUSIVIDAD_ACTOR(),
    FN_M3_BLOQUEAR_CATEGORIA(), FN_M3_MIEMBROS_CATEGORIA(INTEGER,TEXT,TEXT,TEXT[]),
    FN_M3_EXCLUSIVIDAD_CATEGORIA(), FN_M3_PERFIL_RUTA(TEXT,TEXT,TEXT), FN_M3_EXCLUSIVIDAD_RUTA(),
    FN_M3_EXPERIENCIA_CON_DETALLE(), FN_M3_BLOQUEAR_EXPERIENCIA(), FN_M3_HORARIO_SERVICIO(INTEGER,TIMESTAMP),
    FN_M3_VALIDAR_CREDENCIAL(), FN_M3_VALIDAR_EVALUACION(), FN_M3_VALIDAR_INCIDENCIA(),
    FN_M3_VALIDAR_PRORROGA(), FN_M3_COMPETENCIA_INCIDENCIA(INTEGER,INTEGER),
    FN_M3_EMITIR_CREDENCIAL(TEXT,TIMESTAMP,NUMERIC,INTEGER,INTEGER,INTEGER),
    FN_M3_REPORTAR_INCIDENCIA(TIMESTAMP,DATE,TEXT,TEXT,INTEGER) FROM PUBLIC;
REVOKE EXECUTE ON PROCEDURE SP_CANJEAR_CREDENCIAL(TEXT), SP_M3_ESTADO_CREDENCIAL(TEXT,TEXT),
    SP_CONFIRMAR_INCIDENCIA(INTEGER,TEXT,DATE), SP_PRORROGAR_INCIDENCIA(INTEGER,DATE,TEXT),
    SP_CERRAR_INCIDENCIA(INTEGER) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION FN_M3_HORARIO_SERVICIO(INTEGER,TIMESTAMP) TO rol_visitante, rol_guia, rol_comercio, rol_admin_rutas;
GRANT EXECUTE ON FUNCTION FN_M3_EMITIR_CREDENCIAL(TEXT,TIMESTAMP,NUMERIC,INTEGER,INTEGER,INTEGER) TO rol_visitante;
GRANT EXECUTE ON FUNCTION FN_M3_REPORTAR_INCIDENCIA(TIMESTAMP,DATE,TEXT,TEXT,INTEGER)
    TO rol_visitante, rol_guia, rol_ente_publico, rol_admin_rutas;
GRANT EXECUTE ON FUNCTION FN_M3_COMPETENCIA_INCIDENCIA(INTEGER,INTEGER) TO rol_ente_publico, rol_admin_rutas;
GRANT EXECUTE ON PROCEDURE SP_CANJEAR_CREDENCIAL(TEXT) TO rol_guia, rol_comercio;
GRANT EXECUTE ON PROCEDURE SP_M3_ESTADO_CREDENCIAL(TEXT,TEXT) TO rol_visitante, rol_admin_rutas;
GRANT EXECUTE ON PROCEDURE SP_CONFIRMAR_INCIDENCIA(INTEGER,TEXT,DATE), SP_PRORROGAR_INCIDENCIA(INTEGER,DATE,TEXT),
    SP_CERRAR_INCIDENCIA(INTEGER) TO rol_ente_publico, rol_admin_rutas;
GRANT SELECT ON VW_M3_BANDEJA_INSTITUCIONAL TO rol_ente_publico, rol_admin_rutas;

COMMIT;
