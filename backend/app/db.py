"""
============================================================================
Archivo: backend/app/db.py
Módulo: Base común (Paso 0 - Contratos Congelados)
Descripción: Gestión de conexiones PostgreSQL con psycopg2 (SQL puro, sin ORM),
             serialización JSON limpia, paginación y ordenamiento seguro por
             lista blanca, y traducción de errores del SGBD a códigos HTTP.
============================================================================
"""
from __future__ import annotations

import math
import os
from contextlib import contextmanager
from datetime import date, datetime, time
from decimal import Decimal
from pathlib import Path
from typing import Any, Iterator

import psycopg2
import psycopg2.extras
from dotenv import load_dotenv
from fastapi import HTTPException

REPO_ROOT = Path(__file__).resolve().parents[2]
ENV_PATH = REPO_ROOT / ".env"
ENV_EXAMPLE_PATH = REPO_ROOT / ".env.example"

if ENV_PATH.exists():
    load_dotenv(ENV_PATH)
elif ENV_EXAMPLE_PATH.exists():
    load_dotenv(ENV_EXAMPLE_PATH)


def get_db_config() -> dict[str, Any]:
    return {
        "host": os.getenv("POSTGRES_HOST", "localhost"),
        "port": int(os.getenv("POSTGRES_PORT", "5432")),
        "dbname": os.getenv("POSTGRES_DB", "rutas_venezuela_db"),
        "user": os.getenv("POSTGRES_USER", "admin_rutas"),
        "password": os.getenv("POSTGRES_PASSWORD", "rutas_dev_password_2026"),
    }


def serialize_value(val: Any) -> Any:
    if isinstance(val, Decimal):
        return float(val)
    if isinstance(val, (datetime, date, time)):
        return val.isoformat()
    return val


def serialize_row(row: dict[str, Any] | None) -> dict[str, Any] | None:
    if row is None:
        return None
    return {k: serialize_value(v) for k, v in row.items()}


def serialize_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [serialize_row(r) for r in rows if r is not None]


def raise_http_for_pg_error(exc: psycopg2.Error) -> None:
    sqlstate = getattr(exc, "pgcode", None)
    diag = getattr(exc, "diag", None)
    primary_msg = getattr(diag, "message_primary", None) if diag else None
    raw_msg = primary_msg or (exc.pgerror.splitlines()[0] if exc.pgerror else str(exc))

    if sqlstate == "23505":
        raise HTTPException(status_code=409, detail=f"Conflicto de unicidad: {raw_msg}")
    if sqlstate == "23503":
        raise HTTPException(
            status_code=409,
            detail=f"Violación de integridad referencial: {raw_msg}",
        )
    if sqlstate in {"23514", "23502", "P0001", "22P02", "22003", "22007"}:
        raise HTTPException(status_code=400, detail=raw_msg)
    if sqlstate == "42501":
        raise HTTPException(status_code=403, detail=f"Privilegios insuficientes: {raw_msg}")
    raise HTTPException(status_code=500, detail=f"Error de base de datos ({sqlstate}): {raw_msg}")


@contextmanager
def get_db_cursor(commit: bool = False) -> Iterator[psycopg2.extras.RealDictCursor]:
    conn = psycopg2.connect(**get_db_config())
    conn.autocommit = False
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            yield cur
        if commit:
            conn.commit()
    except HTTPException:
        conn.rollback()
        raise
    except psycopg2.Error as exc:
        conn.rollback()
        raise_http_for_pg_error(exc)
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def paginate_query(
    cur: psycopg2.extras.RealDictCursor,
    base_from_where: str,
    select_cols: str,
    params: dict[str, Any],
    sort_by: str | None,
    sort_dir: str,
    allowed_sort: dict[str, str],
    default_sort: str,
    page: int = 1,
    page_size: int = 10,
) -> dict[str, Any]:
    """
    Ejecuta consulta paginada y ordenada con SQL puro parametrizado.
    Cumple estrictamente el contrato de Paso 0 y cero subconsultas en SELECT/FROM.
    """
    safe_page = max(1, page)
    safe_size = max(1, min(100, page_size))

    selected_key = sort_by if (sort_by and sort_by in allowed_sort) else default_sort
    order_expr = allowed_sort[selected_key]

    norm_dir = "desc" if str(sort_dir).lower() == "desc" else "asc"
    dir_sql = "DESC" if norm_dir == "desc" else "ASC"

    count_sql = f"SELECT COUNT(*) AS total FROM {base_from_where}"
    cur.execute(count_sql, params)
    total = int(cur.fetchone()["total"])

    total_pages = max(1, math.ceil(total / safe_size)) if total > 0 else 1
    if safe_page > total_pages:
        safe_page = total_pages
    offset = (safe_page - 1) * safe_size

    query_params = dict(params)
    query_params["limit"] = safe_size
    query_params["offset"] = offset

    data_sql = (
        f"SELECT {select_cols} FROM {base_from_where} "
        f"ORDER BY {order_expr} {dir_sql} "
        f"LIMIT %(limit)s OFFSET %(offset)s"
    )
    cur.execute(data_sql, query_params)
    items = serialize_rows(cur.fetchall())

    return {
        "items": items,
        "total": total,
        "page": safe_page,
        "page_size": safe_size,
        "total_pages": total_pages,
        "sort_by": selected_key,
        "sort_dir": norm_dir,
    }
