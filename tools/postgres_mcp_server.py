"""Servidor MCP (Stdio JSON-RPC 2.0) local para PostgreSQL de Rutas Venezuela."""
from __future__ import annotations

import datetime
import decimal
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

import psycopg2
import psycopg2.extras


REPO_ROOT = Path(__file__).resolve().parent.parent


def _load_env_defaults() -> dict[str, str]:
    defaults: dict[str, str] = {}
    for filename in (".env.example", ".env"):
        env_path = REPO_ROOT / filename
        if not env_path.is_file():
            continue
        for line in env_path.read_text(encoding="utf-8").splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("#") or "=" not in stripped:
                continue
            key, val = stripped.split("=", 1)
            defaults[key.strip()] = val.strip().strip('"').strip("'")
    return defaults


def _db_config() -> dict[str, Any]:
    file_defaults = _load_env_defaults()
    return {
        "host": os.environ.get("POSTGRES_HOST", file_defaults.get("POSTGRES_HOST", "localhost")),
        "port": int(os.environ.get("POSTGRES_PORT", file_defaults.get("POSTGRES_PORT", "5432"))),
        "dbname": os.environ.get("POSTGRES_DB", file_defaults.get("POSTGRES_DB", "rutas_venezuela_db")),
        "user": os.environ.get("POSTGRES_USER", file_defaults.get("POSTGRES_USER", "admin_rutas")),
        "password": os.environ.get("POSTGRES_PASSWORD", file_defaults.get("POSTGRES_PASSWORD", "rutas_dev_password_2026")),
    }


def _allow_write() -> bool:
    return os.environ.get("MCP_ALLOW_WRITE", "false").strip().lower() in ("1", "true", "yes")


def _json_default(obj: Any) -> Any:
    if isinstance(obj, (decimal.Decimal,)):
        return float(obj)
    if isinstance(obj, (datetime.datetime, datetime.date, datetime.time)):
        return obj.isoformat()
    if isinstance(obj, bytes):
        return obj.decode("utf-8", errors="replace")
    return str(obj)


def _connect():
    cfg = _db_config()
    return psycopg2.connect(**cfg)


def _is_readonly_sql(sql: str) -> bool:
    cleaned = re.sub(r"--[^\n]*", "", sql)
    cleaned = re.sub(r"/\*.*?\*/", "", cleaned, flags=re.S).strip()
    if not cleaned:
        return False
    # Disallow stacked statements in read-only mode (ignore trailing semicolon)
    body = cleaned[:-1] if cleaned.endswith(";") else cleaned
    if ";" in body:
        return False
    first_word = body.split(None, 1)[0].upper()
    return first_word in ("SELECT", "SHOW", "EXPLAIN", "WITH", "VALUES")


def tool_pg_query(args: dict[str, Any]) -> dict[str, Any]:
    sql = str(args.get("sql", "")).strip()
    if not sql:
        raise ValueError("El parametro 'sql' es obligatorio.")
    readonly = not _allow_write()
    if readonly and not _is_readonly_sql(sql):
        raise PermissionError(
            "Modo solo lectura activo (MCP_ALLOW_WRITE=false). Solo se permiten sentencias SELECT/WITH/EXPLAIN/SHOW unicas."
        )

    with _connect() as conn:
        if readonly:
            conn.set_session(readonly=True, autocommit=True)
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql)
            if cur.description is not None:
                rows = [dict(r) for r in cur.fetchall()]
                return {"row_count": len(rows), "rows": rows}
            return {"row_count": cur.rowcount, "status": cur.statusmessage}


def tool_pg_list_tables(args: dict[str, Any]) -> dict[str, Any]:
    schema = str(args.get("schema", "public")).strip() or "public"
    sql = """
        SELECT table_name, table_type
        FROM information_schema.tables
        WHERE table_schema = %s
        ORDER BY table_type, table_name;
    """
    with _connect() as conn:
        conn.set_session(readonly=True, autocommit=True)
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, (schema,))
            rows = [dict(r) for r in cur.fetchall()]
    return {"schema": schema, "count": len(rows), "tables": rows}


def tool_pg_describe_table(args: dict[str, Any]) -> dict[str, Any]:
    table_name = str(args.get("table_name", "")).strip()
    schema = str(args.get("schema", "public")).strip() or "public"
    if not table_name:
        raise ValueError("El parametro 'table_name' es obligatorio.")

    cols_sql = """
        SELECT column_name, data_type, udt_name, is_nullable, column_default,
               numeric_precision, numeric_scale, character_maximum_length
        FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s
        ORDER BY ordinal_position;
    """
    cons_sql = """
        SELECT con.conname AS constraint_name,
               con.contype AS constraint_type,
               pg_get_constraintdef(con.oid, true) AS definition
        FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
        WHERE nsp.nspname = %s AND rel.relname = %s
        ORDER BY con.contype, con.conname;
    """
    idx_sql = """
        SELECT indexname, indexdef
        FROM pg_indexes
        WHERE schemaname = %s AND tablename = %s
        ORDER BY indexname;
    """
    with _connect() as conn:
        conn.set_session(readonly=True, autocommit=True)
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(cols_sql, (schema, table_name))
            columns = [dict(r) for r in cur.fetchall()]
            cur.execute(cons_sql, (schema, table_name))
            constraints = [dict(r) for r in cur.fetchall()]
            cur.execute(idx_sql, (schema, table_name))
            indexes = [dict(r) for r in cur.fetchall()]
    return {
        "schema": schema,
        "table_name": table_name,
        "columns": columns,
        "constraints": constraints,
        "indexes": indexes,
    }


def tool_pg_list_routines(args: dict[str, Any]) -> dict[str, Any]:
    schema = str(args.get("schema", "public")).strip() or "public"
    routines_sql = """
        SELECT p.proname AS routine_name,
               CASE p.prokind WHEN 'f' THEN 'function' WHEN 'p' THEN 'procedure' ELSE p.prokind::text END AS kind,
               pg_get_function_arguments(p.oid) AS arguments,
               pg_get_function_result(p.oid) AS return_type
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = %s
        ORDER BY kind, routine_name;
    """
    triggers_sql = """
        SELECT event_object_table AS table_name,
               trigger_name,
               action_timing,
               event_manipulation,
               action_statement
        FROM information_schema.triggers
        WHERE trigger_schema = %s
        ORDER BY event_object_table, trigger_name;
    """
    with _connect() as conn:
        conn.set_session(readonly=True, autocommit=True)
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(routines_sql, (schema,))
            routines = [dict(r) for r in cur.fetchall()]
            cur.execute(triggers_sql, (schema,))
            triggers = [dict(r) for r in cur.fetchall()]
    return {"schema": schema, "routines": routines, "triggers": triggers}


TOOLS = [
    {
        "name": "pg_query",
        "description": "Ejecuta una consulta SQL sobre PostgreSQL local de Rutas Venezuela.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "sql": {"type": "string", "description": "Sentencia SQL a ejecutar."}
            },
            "required": ["sql"],
        },
    },
    {
        "name": "pg_list_tables",
        "description": "Lista tablas y vistas del esquema PostgreSQL indicado (por defecto public).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "schema": {"type": "string", "description": "Nombre del esquema (default: public)."}
            },
        },
    },
    {
        "name": "pg_describe_table",
        "description": "Describe columnas, constraints (PK/AK/FK/CHECK) e indices de una tabla.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "table_name": {"type": "string", "description": "Nombre de la tabla (en minusculas si no fue entrecomillada)."},
                "schema": {"type": "string", "description": "Nombre del esquema (default: public)."},
            },
            "required": ["table_name"],
        },
    },
    {
        "name": "pg_list_routines",
        "description": "Lista funciones, procedimientos almacenados y triggers definidos en PostgreSQL.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "schema": {"type": "string", "description": "Nombre del esquema (default: public)."}
            },
        },
    },
]

TOOL_HANDLERS = {
    "pg_query": tool_pg_query,
    "pg_list_tables": tool_pg_list_tables,
    "pg_describe_table": tool_pg_describe_table,
    "pg_list_routines": tool_pg_list_routines,
}


def _send(msg: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(msg, default=_json_default, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def _handle_request(req: dict[str, Any]) -> None:
    req_id = req.get("id")
    method = req.get("method", "")
    params = req.get("params") or {}

    if req_id is None:
        return  # Notification, no response required

    try:
        if method == "initialize":
            client_proto = params.get("protocolVersion", "2024-11-05")
            _send(
                {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "protocolVersion": client_proto,
                        "capabilities": {"tools": {"listChanged": False}},
                        "serverInfo": {"name": "rutas-postgres-mcp", "version": "1.0.0"},
                    },
                }
            )
        elif method == "ping":
            _send({"jsonrpc": "2.0", "id": req_id, "result": {}})
        elif method == "tools/list":
            _send({"jsonrpc": "2.0", "id": req_id, "result": {"tools": TOOLS}})
        elif method == "tools/call":
            name = params.get("name", "")
            args = params.get("arguments") or {}
            handler = TOOL_HANDLERS.get(name)
            if handler is None:
                _send(
                    {
                        "jsonrpc": "2.0",
                        "id": req_id,
                        "error": {"code": -32601, "message": f"Herramienta desconocida: {name}"},
                    }
                )
                return
            try:
                data = handler(args)
                _send(
                    {
                        "jsonrpc": "2.0",
                        "id": req_id,
                        "result": {
                            "content": [{"type": "text", "text": json.dumps(data, default=_json_default, indent=2, ensure_ascii=False)}],
                            "isError": False,
                        },
                    }
                )
            except Exception as exc:
                _send(
                    {
                        "jsonrpc": "2.0",
                        "id": req_id,
                        "result": {
                            "content": [{"type": "text", "text": f"Error ejecutando {name}: {exc}"}],
                            "isError": True,
                        },
                    }
                )
        else:
            _send(
                {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "error": {"code": -32601, "message": f"Metodo no soportado: {method}"},
                }
            )
    except Exception as exc:
        _send({"jsonrpc": "2.0", "id": req_id, "error": {"code": -32603, "message": str(exc)}})


def main() -> None:
    for raw_line in sys.stdin:
        line = raw_line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError as exc:
            _send({"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": f"JSON invalido: {exc}"}})
            continue
        _handle_request(req)


if __name__ == "__main__":
    main()
