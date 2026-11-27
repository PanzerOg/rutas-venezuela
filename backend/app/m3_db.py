# Módulo 3 · Autor responsable: Leonardo Enrique Chacón Agraz - C.I. 31.895.402
import os
from atexit import register
from contextlib import contextmanager
from threading import Lock

from fastapi import HTTPException
from psycopg2 import Error, sql
from psycopg2.extras import RealDictCursor
from psycopg2.pool import PoolError, ThreadedConnectionPool

from .db import get_db_config

_pool = None
_pool_lock = Lock()


def get_pool():
    global _pool
    with _pool_lock:
        if _pool is None:
            config = get_db_config()
            _pool = ThreadedConnectionPool(
                1, 12,
                host=os.environ.get("M3_DB_HOST", config["host"]),
                port=config["port"],
                dbname=config["dbname"],
                user="svc_rutas_web",
                password=os.environ.get("M3_DB_PASSWORD"),
                connect_timeout=4,
                options="-c timezone=America/Caracas -c search_path=public",
            )
        return _pool


@register
def close_pool():
    global _pool
    with _pool_lock:
        if _pool is not None:
            _pool.closeall()
            _pool = None


@contextmanager
def transaction(role, user_id=None):
    pool = None
    conn = None
    try:
        pool = get_pool()
        conn = pool.getconn()
        with conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql.SQL("SET LOCAL ROLE {}").format(sql.Identifier(role)))
            if user_id is not None:
                cur.execute("SELECT set_config('rutas.id_usuario', %s, TRUE)", (str(user_id),))
            yield cur
    except PoolError as exc:
        raise HTTPException(503, "La base de datos está ocupada. Intenta de nuevo.") from exc
    except Error as exc:
        if exc.pgcode == "42501":
            raise HTTPException(403, "Tu perfil no puede realizar esta operación.") from exc
        if exc.pgcode == "23505":
            raise HTTPException(409, "Ya existe un registro con ese identificador.") from exc
        if exc.pgcode == "23503":
            raise HTTPException(409, "Hay una referencia inexistente o un registro relacionado.") from exc
        if exc.pgcode == "23514":
            constraint = exc.diag.constraint_name or ""
            if constraint.endswith("requiere_m2"):
                raise HTTPException(503, "Instala el esquema de rutas del módulo 2 para usar esta opción.") from exc
            message = (
                f"Revisa los valores ingresados ({constraint})."
                if constraint else exc.diag.message_primary
            )
            raise HTTPException(422, message) from exc
        if exc.pgcode and exc.pgcode[:2] in ("22", "23"):
            raise HTTPException(422, "Revisa el formato y los valores ingresados.") from exc
        if exc.pgcode in ("40001", "40P01"):
            raise HTTPException(409, "El registro cambió en otra operación. Intenta de nuevo.") from exc
        if exc.pgcode == "P0002":
            raise HTTPException(403, "El perfil no está habilitado para esta operación.") from exc
        raise HTTPException(503, "No se pudo completar la operación en la base de datos.") from exc
    finally:
        if conn is not None:
            pool.putconn(conn, close=bool(conn.closed))
