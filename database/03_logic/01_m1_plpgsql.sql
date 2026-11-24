-- ============================================================================
-- Archivo: 03_logic/01_m1_plpgsql.sql
-- Módulo: Módulo 1 - Territorio, Hitos Turísticos y Realidad Aumentada
-- Autor responsable: José Alejandro Montes de Oca Tineo - C.I. 31.066.053
-- Descripción: Automatización de reglas de integridad (Triggers), cálculo
--              espacial 3D con tipos primitivos, cursores explícitos (Funciones)
--              y transacciones atómicas (Procedimientos Almacenados) en PL/pgSQL.
--              Cumple lineamientos de cátedra: prefijos TG_/FN_/SP_, variables
--              v_/p_/r_/c_, %TYPE/%ROWTYPE y una variable por línea.
-- ============================================================================

-- ============================================================================
-- SECCIÓN A: FUNCIONES ALMACENADAS
-- ============================================================================

-- 1. FN_CALCULAR_DISTANCIA_3D_M
--    Calcula la distancia euclidiana-geodésica 3D en metros usando únicamente
--    valores numéricos primitivos (Haversine superficial + componente vertical).
CREATE OR REPLACE FUNCTION FN_CALCULAR_DISTANCIA_3D_M (
    p_lat1 NUMERIC,
    p_lon1 NUMERIC,
    p_alt1 NUMERIC,
    p_lat2 NUMERIC,
    p_lon2 NUMERIC,
    p_alt2 NUMERIC
)
RETURNS NUMERIC(12,2)
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_radio_tierra_m CONSTANT NUMERIC(12,2) := 6371000.00;
    v_dlat DOUBLE PRECISION;
    v_dlon DOUBLE PRECISION;
    v_lat1_rad DOUBLE PRECISION;
    v_lat2_rad DOUBLE PRECISION;
    v_a DOUBLE PRECISION;
    v_c DOUBLE PRECISION;
    v_dist_horiz DOUBLE PRECISION;
    v_dist_vert DOUBLE PRECISION;
    v_dist_total NUMERIC(12,2);
BEGIN
    v_dlat := RADIANS((p_lat2 - p_lat1)::DOUBLE PRECISION);
    v_dlon := RADIANS((p_lon2 - p_lon1)::DOUBLE PRECISION);
    v_lat1_rad := RADIANS(p_lat1::DOUBLE PRECISION);
    v_lat2_rad := RADIANS(p_lat2::DOUBLE PRECISION);

    v_a := SIN(v_dlat / 2.0) * SIN(v_dlat / 2.0)
         + COS(v_lat1_rad) * COS(v_lat2_rad)
         * SIN(v_dlon / 2.0) * SIN(v_dlon / 2.0);
    v_c := 2.0 * ASIN(SQRT(LEAST(1.0, GREATEST(0.0, v_a))));
    v_dist_horiz := v_radio_tierra_m * v_c;
    v_dist_vert := ABS((p_alt2 - p_alt1)::DOUBLE PRECISION);

    v_dist_total := ROUND(SQRT(v_dist_horiz * v_dist_horiz + v_dist_vert * v_dist_vert)::NUMERIC, 2);
    RETURN v_dist_total;
END;
$$;

-- 2. FN_CONSULTAR_RA_CERCANA
--    Soporta la Consulta Espacial (M1) y RF-VA-01 (Visor Patrimonial de RA).
--    Usa cursor explícito y %ROWTYPE para recorrer el catálogo de anclajes.
CREATE OR REPLACE FUNCTION FN_CONSULTAR_RA_CERCANA (
    p_latitud      Punto_Anclaje_RA.latitud%TYPE,
    p_longitud     Punto_Anclaje_RA.longitud%TYPE,
    p_elevacion    Punto_Anclaje_RA.altitud_suelo%TYPE,
    p_radio_extra_m NUMERIC DEFAULT 0
)
RETURNS TABLE (
    id_anclaje         INTEGER,
    cod_recurso_3d     VARCHAR(40),
    tipo_recurso       VARCHAR(60),
    descripcion_recurso TEXT,
    nombre_hito        VARCHAR(150),
    nombre_estado      VARCHAR(100),
    nombre_municipio   VARCHAR(120),
    nombre_parroquia   VARCHAR(120),
    estado_hito        VARCHAR(30),
    latitud            NUMERIC(9,6),
    longitud           NUMERIC(9,6),
    altitud_suelo      NUMERIC(8,2),
    azimut             NUMERIC(6,2),
    inclinacion        NUMERIC(5,2),
    rotacion           NUMERIC(6,2),
    radio_activacion_m NUMERIC(8,2),
    escala             NUMERIC(6,3),
    hipervinculo_info  VARCHAR(300),
    distancia_3d_m     NUMERIC(12,2)
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    c_anclajes CURSOR FOR
        SELECT v.*
        FROM VW_M1_ANCLAJES_RA_CATALOGO v
        WHERE v.estado_hito <> 'Cerrado permanentemente'
        ORDER BY v.id_anclaje;
    r_anclaje VW_M1_ANCLAJES_RA_CATALOGO%ROWTYPE;
    v_dist_m NUMERIC(12,2);
    v_radio_efectivo NUMERIC(10,2);
BEGIN
    IF p_latitud < -90 OR p_latitud > 90 THEN
        RAISE EXCEPTION 'Latitud fuera de rango geodésico [-90, 90]: %', p_latitud;
    END IF;
    IF p_longitud < -180 OR p_longitud > 180 THEN
        RAISE EXCEPTION 'Longitud fuera de rango geodésico [-180, 180]: %', p_longitud;
    END IF;
    IF p_elevacion < 0 THEN
        RAISE EXCEPTION 'La elevación no puede ser negativa: %', p_elevacion;
    END IF;
    IF p_radio_extra_m < 0 THEN
        RAISE EXCEPTION 'El radio adicional de búsqueda no puede ser negativo: %', p_radio_extra_m;
    END IF;

    OPEN c_anclajes;
    LOOP
        FETCH c_anclajes INTO r_anclaje;
        EXIT WHEN NOT FOUND;

        v_dist_m := FN_CALCULAR_DISTANCIA_3D_M(
            p_latitud,
            p_longitud,
            p_elevacion,
            r_anclaje.latitud,
            r_anclaje.longitud,
            r_anclaje.altitud_suelo
        );
        v_radio_efectivo := r_anclaje.radio_activacion_m + COALESCE(p_radio_extra_m, 0);

        IF v_dist_m <= v_radio_efectivo THEN
            id_anclaje := r_anclaje.id_anclaje;
            cod_recurso_3d := r_anclaje.cod_recurso_3d;
            tipo_recurso := r_anclaje.tipo_recurso;
            descripcion_recurso := r_anclaje.descripcion_recurso;
            nombre_hito := r_anclaje.nombre_hito;
            nombre_estado := r_anclaje.nombre_estado;
            nombre_municipio := r_anclaje.nombre_municipio;
            nombre_parroquia := r_anclaje.nombre_parroquia;
            estado_hito := r_anclaje.estado_hito;
            latitud := r_anclaje.latitud;
            longitud := r_anclaje.longitud;
            altitud_suelo := r_anclaje.altitud_suelo;
            azimut := r_anclaje.azimut;
            inclinacion := r_anclaje.inclinacion;
            rotacion := r_anclaje.rotacion;
            radio_activacion_m := r_anclaje.radio_activacion_m;
            escala := r_anclaje.escala;
            hipervinculo_info := r_anclaje.hipervinculo_info;
            distancia_3d_m := v_dist_m;
            RETURN NEXT;
        END IF;
    END LOOP;
    CLOSE c_anclajes;
END;
$$;

-- 3. FN_RESUMEN_CONSERVACION_ESTADO
--    Calcula KPIs de inventario patrimonial usando cursor explícito sobre Hito_Turistico.
CREATE OR REPLACE FUNCTION FN_RESUMEN_CONSERVACION_ESTADO (
    p_cod_estado Estado.cod_estado%TYPE DEFAULT NULL
)
RETURNS TABLE (
    total_hitos             INTEGER,
    disponibles             INTEGER,
    en_restauracion         INTEGER,
    clausurados_temp        INTEGER,
    cerrados_perm           INTEGER,
    deteriorados_o_criticos INTEGER,
    porcentaje_alerta       NUMERIC(5,2)
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    c_hitos CURSOR FOR
        SELECT h.*
        FROM Hito_Turistico h
        WHERE p_cod_estado IS NULL OR h.cod_estado = p_cod_estado;
    r_hito Hito_Turistico%ROWTYPE;
    v_total INTEGER := 0;
    v_disp INTEGER := 0;
    v_rest INTEGER := 0;
    v_claus INTEGER := 0;
    v_cerr INTEGER := 0;
    v_crit INTEGER := 0;
BEGIN
    OPEN c_hitos;
    LOOP
        FETCH c_hitos INTO r_hito;
        EXIT WHEN NOT FOUND;

        v_total := v_total + 1;
        IF r_hito.estado_operativo = 'Disponible' THEN
            v_disp := v_disp + 1;
        ELSIF r_hito.estado_operativo = 'En restauracion' THEN
            v_rest := v_rest + 1;
        ELSIF r_hito.estado_operativo = 'Clausurado temporalmente' THEN
            v_claus := v_claus + 1;
        ELSIF r_hito.estado_operativo = 'Cerrado permanentemente' THEN
            v_cerr := v_cerr + 1;
        END IF;

        IF r_hito.estado_conservacion IN ('Deteriorado', 'Critico') THEN
            v_crit := v_crit + 1;
        END IF;
    END LOOP;
    CLOSE c_hitos;

    total_hitos := v_total;
    disponibles := v_disp;
    en_restauracion := v_rest;
    clausurados_temp := v_claus;
    cerrados_perm := v_cerr;
    deteriorados_o_criticos := v_crit;
    IF v_total > 0 THEN
        porcentaje_alerta := ROUND((v_crit::NUMERIC * 100.0) / v_total::NUMERIC, 2);
    ELSE
        porcentaje_alerta := 0.00;
    END IF;
    RETURN NEXT;
END;
$$;

-- ============================================================================
-- SECCIÓN B: TRIGGERS DE INTEGRIDAD (EVENTO - CONDICIÓN - ACCIÓN)
-- ============================================================================

-- 1. RN-M1-05: No se pueden asignar eventos a un hito 'Cerrado permanentemente'
CREATE OR REPLACE FUNCTION FN_TG_VALIDAR_SEDE_EVENTO_HITO ()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_operativo Hito_Turistico.estado_operativo%TYPE;
BEGIN
    SELECT estado_operativo
    INTO v_estado_operativo
    FROM Hito_Turistico
    WHERE cod_estado = NEW.cod_estado
      AND cod_municipio = NEW.cod_municipio
      AND cod_parroquia = NEW.cod_parroquia
      AND nombre_hito = NEW.nombre_hito;

    IF v_estado_operativo = 'Cerrado permanentemente' THEN
        RAISE EXCEPTION 'RN-M1-05: No se pueden programar eventos en el hito "%" porque está Cerrado permanentemente.',
            NEW.nombre_hito;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER TG_VALIDAR_SEDE_EVENTO_HITO
BEFORE INSERT OR UPDATE ON Sede_De_Evento
FOR EACH ROW
EXECUTE FUNCTION FN_TG_VALIDAR_SEDE_EVENTO_HITO();

-- 2. RN-M1-05 inversa: Impide cerrar permanentemente un hito con eventos activos/futuros
CREATE OR REPLACE FUNCTION FN_TG_VALIDAR_CIERRE_PERMANENTE_HITO ()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_eventos_activos INTEGER := 0;
BEGIN
    IF NEW.estado_operativo = 'Cerrado permanentemente'
       AND OLD.estado_operativo IS DISTINCT FROM 'Cerrado permanentemente' THEN
        SELECT COUNT(*)
        INTO v_eventos_activos
        FROM Sede_De_Evento se
        JOIN Evento_Actividad ev
            ON ev.id_evento = se.id_evento
        WHERE se.cod_estado = NEW.cod_estado
          AND se.cod_municipio = NEW.cod_municipio
          AND se.cod_parroquia = NEW.cod_parroquia
          AND se.nombre_hito = NEW.nombre_hito
          AND ev.fecha_fin > CURRENT_TIMESTAMP;

        IF v_eventos_activos > 0 THEN
            RAISE EXCEPTION 'RN-M1-05: El hito "%" tiene % evento(s) activo(s) o futuro(s) y no puede pasar a Cerrado permanentemente.',
                NEW.nombre_hito, v_eventos_activos;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER TG_VALIDAR_CIERRE_PERMANENTE_HITO
BEFORE UPDATE OF estado_operativo ON Hito_Turistico
FOR EACH ROW
EXECUTE FUNCTION FN_TG_VALIDAR_CIERRE_PERMANENTE_HITO();

-- 3. Validación de no solapamiento de franjas horarias en un mismo día por hito
CREATE OR REPLACE FUNCTION FN_TG_VALIDAR_SOLAPAMIENTO_HORARIO ()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_solapados INTEGER := 0;
BEGIN
    SELECT COUNT(*)
    INTO v_solapados
    FROM Horario_Hito hh
    WHERE hh.cod_estado = NEW.cod_estado
      AND hh.cod_municipio = NEW.cod_municipio
      AND hh.cod_parroquia = NEW.cod_parroquia
      AND hh.nombre_hito = NEW.nombre_hito
      AND hh.dia_semana = NEW.dia_semana
      AND NOT (
          TG_OP = 'UPDATE'
          AND hh.dia_semana = OLD.dia_semana
          AND hh.hora_apertura = OLD.hora_apertura
      )
      AND NEW.hora_apertura < hh.hora_cierre
      AND NEW.hora_cierre > hh.hora_apertura;

    IF v_solapados > 0 THEN
        RAISE EXCEPTION 'El horario % (% - %) se solapa con otro turno existente del hito "%".',
            NEW.dia_semana, NEW.hora_apertura, NEW.hora_cierre, NEW.nombre_hito;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER TG_VALIDAR_SOLAPAMIENTO_HORARIO
BEFORE INSERT OR UPDATE ON Horario_Hito
FOR EACH ROW
EXECUTE FUNCTION FN_TG_VALIDAR_SOLAPAMIENTO_HORARIO();

-- 4. RR-M1-02: Todo hito sin libre acceso (y no cerrado permanentemente) requiere >= 1 horario
CREATE OR REPLACE FUNCTION FN_TG_VALIDAR_HITO_HORARIO_NO_LIBRE ()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_cod_estado Hito_Turistico.cod_estado%TYPE;
    v_cod_municipio Hito_Turistico.cod_municipio%TYPE;
    v_cod_parroquia Hito_Turistico.cod_parroquia%TYPE;
    v_nombre_hito Hito_Turistico.nombre_hito%TYPE;
    v_libre_acceso Hito_Turistico.libre_acceso%TYPE;
    v_estado_operativo Hito_Turistico.estado_operativo%TYPE;
    v_total_horarios INTEGER := 0;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_cod_estado := OLD.cod_estado;
        v_cod_municipio := OLD.cod_municipio;
        v_cod_parroquia := OLD.cod_parroquia;
        v_nombre_hito := OLD.nombre_hito;
    ELSE
        v_cod_estado := NEW.cod_estado;
        v_cod_municipio := NEW.cod_municipio;
        v_cod_parroquia := NEW.cod_parroquia;
        v_nombre_hito := NEW.nombre_hito;
    END IF;

    SELECT libre_acceso, estado_operativo
    INTO v_libre_acceso, v_estado_operativo
    FROM Hito_Turistico
    WHERE cod_estado = v_cod_estado
      AND cod_municipio = v_cod_municipio
      AND cod_parroquia = v_cod_parroquia
      AND nombre_hito = v_nombre_hito;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    IF v_libre_acceso = FALSE AND v_estado_operativo <> 'Cerrado permanentemente' THEN
        SELECT COUNT(*)
        INTO v_total_horarios
        FROM Horario_Hito
        WHERE cod_estado = v_cod_estado
          AND cod_municipio = v_cod_municipio
          AND cod_parroquia = v_cod_parroquia
          AND nombre_hito = v_nombre_hito;

        IF v_total_horarios = 0 THEN
            RAISE EXCEPTION 'RR-M1-02: El hito "%" no es de libre acceso y debe tener al menos un horario registrado en Horario_Hito.',
                v_nombre_hito;
        END IF;
    END IF;

    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER TG_VALIDAR_HITO_HORARIO_NO_LIBRE_HITO
AFTER INSERT OR UPDATE OF libre_acceso, estado_operativo ON Hito_Turistico
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION FN_TG_VALIDAR_HITO_HORARIO_NO_LIBRE();

CREATE CONSTRAINT TRIGGER TG_VALIDAR_HITO_HORARIO_NO_LIBRE_HOR
AFTER DELETE OR UPDATE ON Horario_Hito
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION FN_TG_VALIDAR_HITO_HORARIO_NO_LIBRE();

-- 5. RR-M1-04: Todo hito turístico debe pertenecer al menos a una categoría
CREATE OR REPLACE FUNCTION FN_TG_VALIDAR_HITO_MIN_CATEGORIA ()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_cod_estado Hito_Turistico.cod_estado%TYPE;
    v_cod_municipio Hito_Turistico.cod_municipio%TYPE;
    v_cod_parroquia Hito_Turistico.cod_parroquia%TYPE;
    v_nombre_hito Hito_Turistico.nombre_hito%TYPE;
    v_existe_hito BOOLEAN := FALSE;
    v_total_cat INTEGER := 0;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_cod_estado := OLD.cod_estado;
        v_cod_municipio := OLD.cod_municipio;
        v_cod_parroquia := OLD.cod_parroquia;
        v_nombre_hito := OLD.nombre_hito;
    ELSE
        v_cod_estado := NEW.cod_estado;
        v_cod_municipio := NEW.cod_municipio;
        v_cod_parroquia := NEW.cod_parroquia;
        v_nombre_hito := NEW.nombre_hito;
    END IF;

    SELECT TRUE
    INTO v_existe_hito
    FROM Hito_Turistico
    WHERE cod_estado = v_cod_estado
      AND cod_municipio = v_cod_municipio
      AND cod_parroquia = v_cod_parroquia
      AND nombre_hito = v_nombre_hito;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    SELECT COUNT(*)
    INTO v_total_cat
    FROM Hito_Categoria
    WHERE cod_estado = v_cod_estado
      AND cod_municipio = v_cod_municipio
      AND cod_parroquia = v_cod_parroquia
      AND nombre_hito = v_nombre_hito;

    IF v_total_cat = 0 THEN
        RAISE EXCEPTION 'RR-M1-04: El hito "%" debe estar asociado al menos a una categoría en Hito_Categoria.',
            v_nombre_hito;
    END IF;

    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER TG_VALIDAR_HITO_MIN_CATEGORIA_HITO
AFTER INSERT ON Hito_Turistico
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION FN_TG_VALIDAR_HITO_MIN_CATEGORIA();

CREATE CONSTRAINT TRIGGER TG_VALIDAR_HITO_MIN_CATEGORIA_CAT
AFTER DELETE OR UPDATE ON Hito_Categoria
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION FN_TG_VALIDAR_HITO_MIN_CATEGORIA();

-- 6. RR-M2-04 / RR-M3-02 / RR-M3-07 / RR-M3-13:
--    Exclusividad de categorías U desde Hito_Turistico hacia superclases hermanas (M2/M3 si existen)
CREATE OR REPLACE FUNCTION FN_TG_VALIDAR_EXCLUSIVIDAD_CATEGORIAS_M1 ()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_cnt INTEGER := 0;
BEGIN
    IF to_regclass('public.parada_transporte') IS NOT NULL THEN
        EXECUTE 'SELECT COUNT(*) FROM Parada_Transporte WHERE id_punto_itin = $1'
            INTO v_cnt USING NEW.id_punto_itin;
        IF v_cnt > 0 THEN
            RAISE EXCEPTION 'Exclusividad Punto_Itinerario: id_punto_itin % ya pertenece a Parada_Transporte.', NEW.id_punto_itin;
        END IF;
    END IF;

    IF to_regclass('public.tramo_via') IS NOT NULL THEN
        EXECUTE 'SELECT COUNT(*) FROM Tramo_Via WHERE id_elem_afectable = $1'
            INTO v_cnt USING NEW.id_elem_afectable;
        IF v_cnt > 0 THEN
            RAISE EXCEPTION 'Exclusividad Elemento_Afectable: id_elem_afectable % ya pertenece a Tramo_Via.', NEW.id_elem_afectable;
        END IF;
    END IF;

    IF to_regclass('public.ruta') IS NOT NULL THEN
        EXECUTE 'SELECT COUNT(*) FROM Ruta WHERE id_obj_evaluable = $1'
            INTO v_cnt USING NEW.id_obj_evaluable;
        IF v_cnt > 0 THEN
            RAISE EXCEPTION 'Exclusividad Objeto_Evaluable: id_obj_evaluable % ya pertenece a Ruta.', NEW.id_obj_evaluable;
        END IF;
    END IF;

    IF to_regclass('public.comercio_aliado') IS NOT NULL THEN
        EXECUTE 'SELECT COUNT(*) FROM Comercio_Aliado WHERE id_elem_servicio = $1'
            INTO v_cnt USING NEW.id_elem_servicio;
        IF v_cnt > 0 THEN
            RAISE EXCEPTION 'Exclusividad Elemento_Servicio: id_elem_servicio % ya pertenece a Comercio_Aliado.', NEW.id_elem_servicio;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER TG_VALIDAR_EXCLUSIVIDAD_CATEGORIAS_M1
BEFORE INSERT OR UPDATE ON Hito_Turistico
FOR EACH ROW
EXECUTE FUNCTION FN_TG_VALIDAR_EXCLUSIVIDAD_CATEGORIAS_M1();

-- ============================================================================
-- SECCIÓN C: PROCEDIMIENTOS ALMACENADOS TRANSACCIONALES
-- ============================================================================

-- 1. SP_REGISTRAR_HITO_COMPLETO
--    Encapsula el alta atómica de las 4 superclases de categoría, el hito,
--    sus categorías iniciales y (si aplica) un horario inicial.
CREATE OR REPLACE PROCEDURE SP_REGISTRAR_HITO_COMPLETO (
    IN p_cod_estado          Hito_Turistico.cod_estado%TYPE,
    IN p_cod_municipio       Hito_Turistico.cod_municipio%TYPE,
    IN p_cod_parroquia       Hito_Turistico.cod_parroquia%TYPE,
    IN p_nombre_hito         Hito_Turistico.nombre_hito%TYPE,
    IN p_descripcion         Hito_Turistico.descripcion%TYPE,
    IN p_estado_operativo    Hito_Turistico.estado_operativo%TYPE,
    IN p_libre_acceso        Hito_Turistico.libre_acceso%TYPE,
    IN p_estado_conservacion Hito_Turistico.estado_conservacion%TYPE,
    IN p_latitud             Hito_Turistico.latitud%TYPE,
    IN p_longitud            Hito_Turistico.longitud%TYPE,
    IN p_elevacion           Hito_Turistico.elevacion%TYPE,
    IN p_categorias          INTEGER[],
    IN p_dia_semana          Horario_Hito.dia_semana%TYPE DEFAULT NULL,
    IN p_hora_apertura       Horario_Hito.hora_apertura%TYPE DEFAULT NULL,
    IN p_hora_cierre         Horario_Hito.hora_cierre%TYPE DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_punto_itin     Punto_Itinerario.id_punto_itin%TYPE;
    v_id_elem_afectable Elemento_Afectable.id_elem_afectable%TYPE;
    v_id_obj_evaluable  Objeto_Evaluable.id_obj_evaluable%TYPE;
    v_id_elem_servicio  Elemento_Servicio.id_elem_servicio%TYPE;
    v_id_cat            Categoria.id_categoria%TYPE;
BEGIN
    IF p_categorias IS NULL OR COALESCE(ARRAY_LENGTH(p_categorias, 1), 0) = 0 THEN
        RAISE EXCEPTION 'RR-M1-04: Debe suministrar al menos una categoría al registrar el hito "%".', p_nombre_hito;
    END IF;

    INSERT INTO Punto_Itinerario DEFAULT VALUES RETURNING id_punto_itin INTO v_id_punto_itin;
    INSERT INTO Elemento_Afectable DEFAULT VALUES RETURNING id_elem_afectable INTO v_id_elem_afectable;
    INSERT INTO Objeto_Evaluable DEFAULT VALUES RETURNING id_obj_evaluable INTO v_id_obj_evaluable;
    INSERT INTO Elemento_Servicio DEFAULT VALUES RETURNING id_elem_servicio INTO v_id_elem_servicio;

    INSERT INTO Hito_Turistico (
        cod_estado,
        cod_municipio,
        cod_parroquia,
        nombre_hito,
        descripcion,
        estado_operativo,
        libre_acceso,
        estado_conservacion,
        latitud,
        longitud,
        elevacion,
        id_punto_itin,
        id_elem_afectable,
        id_obj_evaluable,
        id_elem_servicio
    ) VALUES (
        p_cod_estado,
        p_cod_municipio,
        p_cod_parroquia,
        p_nombre_hito,
        p_descripcion,
        p_estado_operativo,
        p_libre_acceso,
        p_estado_conservacion,
        p_latitud,
        p_longitud,
        p_elevacion,
        v_id_punto_itin,
        v_id_elem_afectable,
        v_id_obj_evaluable,
        v_id_elem_servicio
    );

    FOREACH v_id_cat IN ARRAY p_categorias LOOP
        INSERT INTO Hito_Categoria (
            cod_estado,
            cod_municipio,
            cod_parroquia,
            nombre_hito,
            id_categoria
        ) VALUES (
            p_cod_estado,
            p_cod_municipio,
            p_cod_parroquia,
            p_nombre_hito,
            v_id_cat
        ) ON CONFLICT DO NOTHING;
    END LOOP;

    IF p_dia_semana IS NOT NULL AND p_hora_apertura IS NOT NULL AND p_hora_cierre IS NOT NULL THEN
        INSERT INTO Horario_Hito (
            cod_estado,
            cod_municipio,
            cod_parroquia,
            nombre_hito,
            dia_semana,
            hora_apertura,
            hora_cierre
        ) VALUES (
            p_cod_estado,
            p_cod_municipio,
            p_cod_parroquia,
            p_nombre_hito,
            p_dia_semana,
            p_hora_apertura,
            p_hora_cierre
        );
    END IF;
END;
$$;

-- 2. SP_PROGRAMAR_EVENTO_SEDE
--    Crea un evento cultural y lo adscribe a un hito sede en la misma operación.
CREATE OR REPLACE PROCEDURE SP_PROGRAMAR_EVENTO_SEDE (
    IN  p_titulo        Evento_Actividad.titulo%TYPE,
    IN  p_descripcion   Evento_Actividad.descripcion%TYPE,
    IN  p_tipo_evento   Evento_Actividad.tipo_evento%TYPE,
    IN  p_fecha_inicio  Evento_Actividad.fecha_inicio%TYPE,
    IN  p_fecha_fin     Evento_Actividad.fecha_fin%TYPE,
    IN  p_cod_estado    Hito_Turistico.cod_estado%TYPE,
    IN  p_cod_municipio Hito_Turistico.cod_municipio%TYPE,
    IN  p_cod_parroquia Hito_Turistico.cod_parroquia%TYPE,
    IN  p_nombre_hito   Hito_Turistico.nombre_hito%TYPE,
    OUT p_id_evento     Evento_Actividad.id_evento%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO Evento_Actividad (
        titulo,
        descripcion,
        tipo_evento,
        fecha_inicio,
        fecha_fin
    ) VALUES (
        p_titulo,
        p_descripcion,
        p_tipo_evento,
        p_fecha_inicio,
        p_fecha_fin
    )
    RETURNING id_evento INTO p_id_evento;

    INSERT INTO Sede_De_Evento (
        id_evento,
        cod_estado,
        cod_municipio,
        cod_parroquia,
        nombre_hito
    ) VALUES (
        p_id_evento,
        p_cod_estado,
        p_cod_municipio,
        p_cod_parroquia,
        p_nombre_hito
    );
END;
$$;

-- 3. SP_CLONAR_RECURSO_ANCLAJE
--    Desacopla la reutilización de un Recurso_3D en un nuevo Punto_Anclaje_RA (RF-CRUD-03).
CREATE OR REPLACE PROCEDURE SP_CLONAR_RECURSO_ANCLAJE (
    IN  p_cod_recurso_3d     Recurso_3D.cod_recurso_3d%TYPE,
    IN  p_cod_estado         Hito_Turistico.cod_estado%TYPE,
    IN  p_cod_municipio      Hito_Turistico.cod_municipio%TYPE,
    IN  p_cod_parroquia      Hito_Turistico.cod_parroquia%TYPE,
    IN  p_nombre_hito        Hito_Turistico.nombre_hito%TYPE,
    IN  p_latitud            Punto_Anclaje_RA.latitud%TYPE,
    IN  p_longitud           Punto_Anclaje_RA.longitud%TYPE,
    IN  p_altitud_suelo      Punto_Anclaje_RA.altitud_suelo%TYPE,
    IN  p_azimut             Punto_Anclaje_RA.azimut%TYPE,
    IN  p_inclinacion        Punto_Anclaje_RA.inclinacion%TYPE,
    IN  p_rotacion           Punto_Anclaje_RA.rotacion%TYPE,
    IN  p_radio_activacion_m Punto_Anclaje_RA.radio_activacion_m%TYPE,
    IN  p_escala             Punto_Anclaje_RA.escala%TYPE,
    IN  p_hipervinculo_info  Punto_Anclaje_RA.hipervinculo_info%TYPE,
    OUT p_id_anclaje         Punto_Anclaje_RA.id_anclaje%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existe_rec BOOLEAN := FALSE;
BEGIN
    SELECT TRUE
    INTO v_existe_rec
    FROM Recurso_3D
    WHERE cod_recurso_3d = p_cod_recurso_3d;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El recurso 3D "%" no existe en el catálogo.', p_cod_recurso_3d;
    END IF;

    INSERT INTO Punto_Anclaje_RA (
        latitud,
        longitud,
        altitud_suelo,
        azimut,
        inclinacion,
        rotacion,
        radio_activacion_m,
        escala,
        hipervinculo_info,
        cod_estado,
        cod_municipio,
        cod_parroquia,
        nombre_hito,
        cod_recurso_3d
    ) VALUES (
        p_latitud,
        p_longitud,
        p_altitud_suelo,
        p_azimut,
        p_inclinacion,
        p_rotacion,
        p_radio_activacion_m,
        p_escala,
        p_hipervinculo_info,
        p_cod_estado,
        p_cod_municipio,
        p_cod_parroquia,
        p_nombre_hito,
        p_cod_recurso_3d
    )
    RETURNING id_anclaje INTO p_id_anclaje;
END;
$$;

-- ============================================================================
-- SECCIÓN D: PRIVILEGIOS DE EJECUCIÓN SOBRE RUTINAS M1
-- ============================================================================

GRANT EXECUTE ON FUNCTION FN_CALCULAR_DISTANCIA_3D_M(NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC)
    TO rol_admin_rutas, rol_ente_publico, rol_visitante, rol_guia, rol_comercio, rol_reportes;

GRANT EXECUTE ON FUNCTION FN_CONSULTAR_RA_CERCANA(NUMERIC, NUMERIC, NUMERIC, NUMERIC)
    TO rol_admin_rutas, rol_ente_publico, rol_visitante, rol_guia, rol_comercio, rol_reportes;

GRANT EXECUTE ON FUNCTION FN_RESUMEN_CONSERVACION_ESTADO(VARCHAR)
    TO rol_admin_rutas, rol_ente_publico, rol_visitante, rol_guia, rol_comercio, rol_reportes;

GRANT EXECUTE ON PROCEDURE SP_REGISTRAR_HITO_COMPLETO(
    VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT, VARCHAR, BOOLEAN, VARCHAR,
    NUMERIC, NUMERIC, NUMERIC, INTEGER[], VARCHAR, TIME, TIME
) TO rol_admin_rutas, rol_ente_publico;

GRANT EXECUTE ON PROCEDURE SP_PROGRAMAR_EVENTO_SEDE(
    VARCHAR, TEXT, VARCHAR, TIMESTAMP, TIMESTAMP, VARCHAR, VARCHAR, VARCHAR, VARCHAR
) TO rol_admin_rutas, rol_ente_publico;

GRANT EXECUTE ON PROCEDURE SP_CLONAR_RECURSO_ANCLAJE(
    VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR,
    NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, VARCHAR
) TO rol_admin_rutas, rol_ente_publico;
