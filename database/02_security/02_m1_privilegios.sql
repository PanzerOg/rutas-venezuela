-- ============================================================================
-- Archivo: 02_m1_privilegios.sql
-- Módulo: Módulo 1 - Territorio, Hitos Turísticos y Realidad Aumentada
-- Autor responsable: José Alejandro Montes de Oca Tineo - C.I. 31.066.053
-- Descripción: Seguridad lógica (DCL) idempotente para Módulo 1: roles del
--              sistema, cuentas operativas, privilegios de sistema y
--              privilegios granulares sobre tablas, vistas y secuencias.
-- ============================================================================

-- 1. Creación idempotente de roles base del proyecto y cuentas de prueba M1
--    (Permite que 02_m1_privilegios.sql funcione tanto autónomo como junto a 01_roles_y_cuentas.sql)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_admin_rutas') THEN
        CREATE ROLE rol_admin_rutas NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_visitante') THEN
        CREATE ROLE rol_visitante NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_guia') THEN
        CREATE ROLE rol_guia NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_comercio') THEN
        CREATE ROLE rol_comercio NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_ente_publico') THEN
        CREATE ROLE rol_ente_publico NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_reportes') THEN
        CREATE ROLE rol_reportes NOLOGIN;
    END IF;

    -- Cuentas de usuario PostgreSQL para demostración de seguridad por rol
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_reportes') THEN
        CREATE USER usr_reportes WITH PASSWORD 'rutas_reportes_2026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_visitante_m1') THEN
        CREATE USER usr_visitante_m1 WITH PASSWORD 'rutas_visitante_2026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_ente_m1') THEN
        CREATE USER usr_ente_m1 WITH PASSWORD 'rutas_ente_2026';
    END IF;

    EXECUTE format(
        'GRANT CONNECT ON DATABASE %I TO rol_admin_rutas, rol_visitante, rol_guia, rol_comercio, rol_ente_publico, rol_reportes',
        current_database()
    );
END
$$;

GRANT rol_reportes     TO usr_reportes;
GRANT rol_visitante    TO usr_visitante_m1;
GRANT rol_ente_publico TO usr_ente_m1;

-- 2. Privilegios de sistema sobre esquema public
GRANT USAGE ON SCHEMA public TO rol_admin_rutas, rol_visitante, rol_guia, rol_comercio, rol_ente_publico, rol_reportes;

-- 3. Principio de mínimo privilegio: revocar acceso público implícito en objetos M1
REVOKE ALL ON TABLE
    Punto_Itinerario,
    Elemento_Afectable,
    Objeto_Evaluable,
    Elemento_Servicio,
    Validador_Acceso,
    Reportante,
    Estado,
    Municipio,
    Parroquia,
    Hito_Turistico,
    Categoria,
    Hito_Categoria,
    Horario_Hito,
    Evento_Actividad,
    Sede_De_Evento,
    Recurso_3D,
    Punto_Anclaje_RA
FROM PUBLIC;

REVOKE ALL ON TABLE
    VW_M1_FICHA_HITO,
    VW_M1_INVENTARIO_PATRIMONIAL,
    VW_M1_INVENTARIO_PATRIMONIAL_CAT,
    VW_M1_CONSULTA_PATRIMONIAL_FDS,
    VW_M1_ANCLAJES_RA_CATALOGO,
    VW_M1_AGENDA_EVENTOS
FROM PUBLIC;

-- 4. Privilegios de objeto para roles de consulta (Visitante, Guía, Comercio)
GRANT SELECT ON TABLE
    Estado,
    Municipio,
    Parroquia,
    Hito_Turistico,
    Categoria,
    Hito_Categoria,
    Horario_Hito,
    Evento_Actividad,
    Sede_De_Evento,
    Recurso_3D,
    Punto_Anclaje_RA,
    VW_M1_FICHA_HITO,
    VW_M1_INVENTARIO_PATRIMONIAL,
    VW_M1_INVENTARIO_PATRIMONIAL_CAT,
    VW_M1_CONSULTA_PATRIMONIAL_FDS,
    VW_M1_ANCLAJES_RA_CATALOGO,
    VW_M1_AGENDA_EVENTOS
TO rol_visitante, rol_guia, rol_comercio;

-- 5. Privilegios para rol dedicado a reportes estratégicos (Jaspersoft / BI)
GRANT SELECT ON TABLE
    Estado,
    Municipio,
    Parroquia,
    Categoria,
    VW_M1_FICHA_HITO,
    VW_M1_INVENTARIO_PATRIMONIAL,
    VW_M1_INVENTARIO_PATRIMONIAL_CAT,
    VW_M1_CONSULTA_PATRIMONIAL_FDS,
    VW_M1_ANCLAJES_RA_CATALOGO,
    VW_M1_AGENDA_EVENTOS
TO rol_reportes;

-- 6. Privilegios para Ente Público Patrimonial (gestión operativa M1 sin borrar territorio)
GRANT SELECT ON TABLE
    Estado,
    Municipio,
    Parroquia,
    Categoria,
    VW_M1_FICHA_HITO,
    VW_M1_INVENTARIO_PATRIMONIAL,
    VW_M1_INVENTARIO_PATRIMONIAL_CAT,
    VW_M1_CONSULTA_PATRIMONIAL_FDS,
    VW_M1_ANCLAJES_RA_CATALOGO,
    VW_M1_AGENDA_EVENTOS
TO rol_ente_publico;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
    Hito_Turistico,
    Hito_Categoria,
    Horario_Hito,
    Evento_Actividad,
    Sede_De_Evento,
    Recurso_3D,
    Punto_Anclaje_RA
TO rol_ente_publico;

GRANT SELECT, INSERT ON TABLE
    Punto_Itinerario,
    Elemento_Afectable,
    Objeto_Evaluable,
    Elemento_Servicio
TO rol_ente_publico;

GRANT USAGE, SELECT ON SEQUENCE
    punto_itinerario_id_punto_itin_seq,
    elemento_afectable_id_elem_afectable_seq,
    objeto_evaluable_id_obj_evaluable_seq,
    elemento_servicio_id_elem_servicio_seq,
    evento_actividad_id_evento_seq,
    punto_anclaje_ra_id_anclaje_seq
TO rol_ente_publico;

-- 7. Privilegios totales para Administrador del Sistema
GRANT ALL PRIVILEGES ON TABLE
    Punto_Itinerario,
    Elemento_Afectable,
    Objeto_Evaluable,
    Elemento_Servicio,
    Validador_Acceso,
    Reportante,
    Estado,
    Municipio,
    Parroquia,
    Hito_Turistico,
    Categoria,
    Hito_Categoria,
    Horario_Hito,
    Evento_Actividad,
    Sede_De_Evento,
    Recurso_3D,
    Punto_Anclaje_RA,
    VW_M1_FICHA_HITO,
    VW_M1_INVENTARIO_PATRIMONIAL,
    VW_M1_INVENTARIO_PATRIMONIAL_CAT,
    VW_M1_CONSULTA_PATRIMONIAL_FDS,
    VW_M1_ANCLAJES_RA_CATALOGO,
    VW_M1_AGENDA_EVENTOS
TO rol_admin_rutas;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rol_admin_rutas;
