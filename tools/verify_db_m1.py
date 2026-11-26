"""
============================================================================
Archivo: tools/verify_db_m1.py
Módulo: Módulo 1 - Territorio, Hitos Turísticos y Realidad Aumentada
Autor responsable: José Alejandro Montes de Oca Tineo - C.I. 31.066.053
Descripción: Carga los 7 scripts SQL del Módulo 1 en PostgreSQL y ejecuta
             pruebas integrales de DDL, DCL, PL/pgSQL, Seeds y JRXML.
============================================================================
"""
from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path
import psycopg2
import psycopg2.extras

DB_CFG = {
    "host": "localhost",
    "port": 5432,
    "dbname": "rutas_venezuela_db",
    "user": "admin_rutas",
    "password": "rutas_dev_password_2026",
}

REPO = Path(r"d:\Contenido para la Segunda Entrega Bases de Datos\rutas-venezuela")

SQL_ORDER = [
    REPO / "database/01_ddl/00_drop_all.sql",
    REPO / "database/01_ddl/01_categorias_base.sql",
    REPO / "database/01_ddl/02_m1_territorio_hitos_ra.sql",
    REPO / "database/01_ddl/06_m1_vistas_indices.sql",
    REPO / "database/02_security/02_m1_privilegios.sql",
    REPO / "database/03_logic/01_m1_plpgsql.sql",
    REPO / "database/04_seeds/01_m1_seeds.sql",
]


def load_scripts():
    conn = psycopg2.connect(**DB_CFG)
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            for path in SQL_ORDER:
                sql = path.read_text(encoding="utf-8")
                print(f"Ejecutando: {path.relative_to(REPO)} ...")
                cur.execute(sql)
        print("[OK] Todos los 7 scripts SQL M1 se ejecutaron sin errores.")
    finally:
        conn.close()


def check_counts():
    tables = [
        "punto_itinerario", "elemento_afectable", "objeto_evaluable", "elemento_servicio",
        "estado", "municipio", "parroquia", "hito_turistico", "categoria",
        "hito_categoria", "horario_hito", "evento_actividad", "sede_de_evento",
        "recurso_3d", "punto_anclaje_ra",
        "vw_m1_ficha_hito", "vw_m1_inventario_patrimonial",
        "vw_m1_inventario_patrimonial_cat", "vw_m1_consulta_patrimonial_fds",
        "vw_m1_anclajes_ra_catalogo", "vw_m1_agenda_eventos",
    ]
    with psycopg2.connect(**DB_CFG) as conn:
        with conn.cursor() as cur:
            for t in tables:
                cur.execute(f"SELECT COUNT(*) FROM {t};")
                # pyrefly: ignore[unsupported-operation]
                cnt = cur.fetchone()[0]
                assert cnt > 0, f"Tabla/vista vacia: {t}"
                print(f"  {t:34s} -> {cnt} filas")


def expect_fail(cur, label, fn):
    cur.execute("SAVEPOINT sp_test;")
    try:
        fn()
    except psycopg2.Error as exc:
        cur.execute("ROLLBACK TO SAVEPOINT sp_test;")
        print(f"  [PASS rechazo esperado] {label}: {exc.pgerror.splitlines()[0] if exc.pgerror else exc}")
        return
    raise AssertionError(f"FALLO: Se esperaba error en '{label}' pero tuvo exito!")


def run_integrity_tests():
    print("\n--- Pruebas de Integridad, PL/pgSQL y Seguridad ---")
    with psycopg2.connect(**DB_CFG) as conn:
        conn.autocommit = False
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            # 1. Homonimia permitida en otra parroquia, rechazada en misma parroquia
            expect_fail(
                cur,
                "RN-M1-01 unicidad hito en misma parroquia",
                lambda: cur.execute(
                    """INSERT INTO Hito_Turistico VALUES
                    ('DC','LIB','CAT','Plaza Bolivar','Duplicado','Disponible',TRUE,'Optimo',
                     10.50,-66.91,900,1,1,1,1);"""
                ),
            )

            # 2. Duplicidad espacial 3D permitida (MACC y Mirador Parque Central)
            cur.execute(
                """SELECT COUNT(*) AS c FROM Hito_Turistico
                   WHERE latitud = 10.498120 AND longitud = -66.900150 AND elevacion = 882.00;"""
            )
            # pyrefly: ignore[unsupported-operation]
            assert cur.fetchone()["c"] == 2, "Debe haber 2 hitos compartiendo coordenada 3D exacta"
            print("  [PASS] Duplicidad espacial 3D verificada (2 hitos en Parque Central)")

            # 3. RN-M1-05: Evento en hito Cerrado permanentemente rechazado por trigger
            expect_fail(
                cur,
                "RN-M1-05 sede cerrada permanentemente",
                lambda: cur.execute(
                    """INSERT INTO Sede_De_Evento (id_evento, cod_estado, cod_municipio, cod_parroquia, nombre_hito)
                       VALUES (1, 'BO', 'ANG', 'CAT', 'Plaza Bolivar');"""
                ),
            )

            # 4. Solapamiento de horario en mismo dia
            expect_fail(
                cur,
                "Solapamiento horario mismo dia",
                lambda: cur.execute(
                    """INSERT INTO Horario_Hito VALUES
                       ('DC','LIB','CAT','Casa Natal del Libertador','Martes','11:00','14:00');"""
                ),
            )

            # 5. Dominios RA y geodesicos
            expect_fail(
                cur,
                "DOM_PUNTO_ANCLAJE_RA__AZIMUT fuera de rango (360)",
                lambda: cur.execute(
                    """INSERT INTO Punto_Anclaje_RA (
                        latitud, longitud, altitud_suelo, azimut, inclinacion, rotacion,
                        radio_activacion_m, escala, hipervinculo_info,
                        cod_estado, cod_municipio, cod_parroquia, nombre_hito, cod_recurso_3d
                    ) VALUES (10.5,-66.9,1.0,360.0,0.0,0.0,100,1.0,'https://x.ve',
                              'DC','LIB','CAT','Plaza Bolivar','MOD3D_CASONA_1783');"""
                ),
            )

            # 6. SP_REGISTRAR_HITO_COMPLETO + FN_CONSULTAR_RA_CERCANA + FN_RESUMEN_CONSERVACION_ESTADO
            cur.execute(
                """CALL SP_REGISTRAR_HITO_COMPLETO(
                    'DC','LIB','CAT','Catedral de Caracas Prueba',
                    'Templo metropolitano de prueba.',
                    'Disponible', FALSE, 'Optimo',
                    10.506550, -66.914200, 901.00,
                    ARRAY[1, 3], 'Sabado', '09:00'::TIME, '17:00'::TIME
                );"""
            )
            cur.execute("SELECT * FROM FN_CONSULTAR_RA_CERCANA(10.506200, -66.914610, 2.00, 0);")
            ra_rows = cur.fetchall()
            assert len(ra_rows) >= 3, f"Esperaba >=3 anclajes RA en Casco Caracas, obtuvo {len(ra_rows)}"
            print(f"  [PASS] FN_CONSULTAR_RA_CERCANA devolvio {len(ra_rows)} anclajes cercanos con distancia 3D")

            cur.execute("SELECT * FROM FN_RESUMEN_CONSERVACION_ESTADO(NULL);")
            kpi = cur.fetchone()
            # pyrefly: ignore[unsupported-operation]
            assert kpi["total_hitos"] == 19  # 18 seeds + 1 prueba en tx
            # pyrefly: ignore[no-matching-overload]
            print("  [PASS] FN_RESUMEN_CONSERVACION_ESTADO:", dict(kpi))

            # 6b. SP_PROGRAMAR_EVENTO_SEDE
            cur.execute(
                """CALL SP_PROGRAMAR_EVENTO_SEDE(
                    'Evento Prueba M1', 'Desc prueba', 'Cultural',
                    '2026-12-01 10:00:00'::TIMESTAMP, '2026-12-01 14:00:00'::TIMESTAMP,
                    'DC', 'LIB', 'CAT', 'Plaza Bolivar', NULL
                );"""
            )
            res_ev = cur.fetchone()
            assert res_ev and res_ev["p_id_evento"] > 0, f"SP_PROGRAMAR_EVENTO_SEDE fallo: {res_ev}"
            print(f"  [PASS] SP_PROGRAMAR_EVENTO_SEDE devolvio p_id_evento={res_ev['p_id_evento']}")

            # 6c. SP_CLONAR_RECURSO_ANCLAJE
            cur.execute(
                """CALL SP_CLONAR_RECURSO_ANCLAJE(
                    'MOD3D_CASONA_1783', 'DC', 'LIB', 'CAT', 'Plaza Bolivar',
                    10.506210, -66.914620, 2.50, 90.00, 0.00, 0.00, 120.00, 1.000,
                    'https://patrimonio.gob.ve/prueba', NULL
                );"""
            )
            res_ra = cur.fetchone()
            assert res_ra and res_ra["p_id_anclaje"] > 0, f"SP_CLONAR_RECURSO_ANCLAJE fallo: {res_ra}"
            print(f"  [PASS] SP_CLONAR_RECURSO_ANCLAJE devolvio p_id_anclaje={res_ra['p_id_anclaje']}")

        conn.rollback()

    # 7. RR-M1-02 y RR-M1-04 (deferred constraint triggers en COMMIT)
    with psycopg2.connect(**DB_CFG) as conn:
        conn.autocommit = False
        try:
            with conn.cursor() as cur:
                cur.execute("INSERT INTO Punto_Itinerario DEFAULT VALUES RETURNING id_punto_itin;")
                # pyrefly: ignore[unsupported-operation]
                p_id = cur.fetchone()[0]
                cur.execute("INSERT INTO Elemento_Afectable DEFAULT VALUES RETURNING id_elem_afectable;")
                # pyrefly: ignore[unsupported-operation]
                a_id = cur.fetchone()[0]
                cur.execute("INSERT INTO Objeto_Evaluable DEFAULT VALUES RETURNING id_obj_evaluable;")
                # pyrefly: ignore[unsupported-operation]
                o_id = cur.fetchone()[0]
                cur.execute("INSERT INTO Elemento_Servicio DEFAULT VALUES RETURNING id_elem_servicio;")
                # pyrefly: ignore[unsupported-operation]
                s_id = cur.fetchone()[0]
                cur.execute(
                    """INSERT INTO Hito_Turistico VALUES
                       ('DC','LIB','CAT','Hito Sin Categoria Ni Horario','Test',
                        'Disponible',FALSE,'Optimo',10.5,-66.9,900,%s,%s,%s,%s);""",
                    (p_id, a_id, o_id, s_id),
                )
            conn.commit()
            raise AssertionError("Debio fallar al hacer COMMIT sin categoria ni horario!")
        except psycopg2.Error as exc:
            conn.rollback()
            print("  [PASS rechazo diferido en COMMIT] RR-M1-02 / RR-M1-04:", str(exc).splitlines()[0])

    # 8. Pruebas de Seguridad Lógica (cuentas por rol)
    with psycopg2.connect(host="localhost", port=5432, dbname="rutas_venezuela_db",
                          user="usr_reportes", password="rutas_reportes_2026") as c_rep:
        with c_rep.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM VW_M1_INVENTARIO_PATRIMONIAL;")
            # pyrefly: ignore[unsupported-operation]
            assert cur.fetchone()[0] == 18
            try:
                cur.execute("DELETE FROM Hito_Turistico;")
                raise AssertionError("usr_reportes no deberia poder borrar!")
            except psycopg2.Error:
                c_rep.rollback()
                print("  [PASS Seguridad] usr_reportes: lee vistas y rechaza DELETE en Hito_Turistico")

    with psycopg2.connect(host="localhost", port=5432, dbname="rutas_venezuela_db",
                          user="usr_visitante_m1", password="rutas_visitante_2026") as c_vis:
        with c_vis.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM VW_M1_CONSULTA_PATRIMONIAL_FDS;")
            # pyrefly: ignore[unsupported-operation]
            cnt_fds = cur.fetchone()[0]
            assert cnt_fds > 0
            try:
                cur.execute("INSERT INTO Categoria (nombre_categoria, descripcion) VALUES ('Hack','x');")
                raise AssertionError("usr_visitante_m1 no deberia poder insertar!")
            except psycopg2.Error:
                c_vis.rollback()
                print(f"  [PASS Seguridad] usr_visitante_m1: lee consulta FDS ({cnt_fds} filas) y rechaza INSERT")

    with psycopg2.connect(host="localhost", port=5432, dbname="rutas_venezuela_db",
                          user="usr_ente_m1", password="rutas_ente_2026") as c_ent:
        with c_ent.cursor() as cur:
            try:
                cur.execute("DELETE FROM Estado WHERE cod_estado = 'DC';")
                raise AssertionError("usr_ente_m1 no deberia poder borrar Estado!")
            except psycopg2.Error:
                c_ent.rollback()
                print("  [PASS Seguridad] usr_ente_m1: rechaza DELETE sobre Estado")


def test_jrxml_query():
    print("\n--- Verificacion SQL del JRXML 01_m1_inventario_patrimonial ---")
    jrxml = REPO / "reports/01_m1_inventario_patrimonial.jrxml"
    tree = ET.parse(jrxml)
    ns = {"jr": "http://jasperreports.sourceforge.net/jasperreports"}
    q_el = tree.find(".//jr:queryString", ns)
    # pyrefly: ignore[missing-attribute]
    raw_sql = q_el.text.strip()
    sql_pg = (
        raw_sql.replace("$P{P_COD_ESTADO}", "%(cod_estado)s")
               .replace("$P{P_COD_MUNICIPIO}", "%(cod_municipio)s")
               .replace("$P{P_COD_PARROQUIA}", "%(cod_parroquia)s")
               .replace("$P{P_ESTADO_OPERATIVO}", "%(estado_operativo)s")
               .replace("$P{P_ID_CATEGORIA}", "%(id_categoria)s")
    )
    with psycopg2.connect(host="localhost", port=5432, dbname="rutas_venezuela_db",
                          user="usr_reportes", password="rutas_reportes_2026") as conn:
        with conn.cursor() as cur:
            cur.execute(sql_pg, {
                "cod_estado": None, "cod_municipio": None, "cod_parroquia": None,
                "estado_operativo": None, "id_categoria": None,
            })
            all_rows = cur.fetchall()
            assert len(all_rows) == 18, f"Esperaba 18 hitos en reporte sin filtros, obtuvo {len(all_rows)}"
            cur.execute(sql_pg, {
                "cod_estado": "DC", "cod_municipio": "LIB", "cod_parroquia": None,
                "estado_operativo": "Disponible", "id_categoria": 1,
            })
            filtered = cur.fetchall()
            assert len(filtered) >= 3
            print(f"  [PASS JRXML] Sin filtros: {len(all_rows)} filas | Filtrado (DC/LIB/Disponible/Cat=1): {len(filtered)} filas")


if __name__ == "__main__":
    load_scripts()
    check_counts()
    run_integrity_tests()
    test_jrxml_query()
    print("\nTODAS LAS VERIFICACIONES DE BASE DE DATOS Y JRXML M1 PASARON.")
