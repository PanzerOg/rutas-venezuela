-- Módulo 3 · Autor responsable: Leonardo Enrique Chacón Agraz - C.I. 31.895.402
BEGIN;

DO $$
DECLARE
    v_rol TEXT;
BEGIN
    EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', current_database());
    FOREACH v_rol IN ARRAY ARRAY[
        'rol_visitante', 'rol_guia', 'rol_comercio', 'rol_ente_publico',
        'rol_admin_rutas', 'rol_reportes', 'rol_m3_autenticacion'
    ] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = v_rol) THEN
            EXECUTE format('CREATE ROLE %I NOLOGIN', v_rol);
        END IF;
        EXECUTE format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), v_rol);
        EXECUTE format('GRANT USAGE ON SCHEMA public TO %I', v_rol);
    END LOOP;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'svc_rutas_web') THEN
        CREATE ROLE svc_rutas_web LOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'svc_rutas_reportes') THEN
        CREATE ROLE svc_rutas_reportes LOGIN;
    END IF;
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO svc_rutas_web, svc_rutas_reportes', current_database());
END;
$$;

GRANT rol_m3_autenticacion, rol_visitante, rol_guia, rol_comercio, rol_ente_publico,
      rol_admin_rutas TO svc_rutas_web;
GRANT rol_reportes TO svc_rutas_reportes;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

\getenv m3_web_password M3_DB_PASSWORD
\if :{?m3_web_password}
ALTER ROLE svc_rutas_web PASSWORD :'m3_web_password';
\endif
\getenv m3_report_password M3_REPORTS_PASSWORD
\if :{?m3_report_password}
ALTER ROLE svc_rutas_reportes PASSWORD :'m3_report_password';
\endif

COMMIT;
