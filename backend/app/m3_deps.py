# Módulo 3 · Autor responsable: Leonardo Enrique Chacón Agraz - C.I. 31.895.402
import base64
import hashlib
import hmac
import json
import os
import time
from typing import Annotated, Literal

from fastapi import Depends, HTTPException, Query
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .m3_db import transaction

ROLES = {
    "Visitante": "rol_visitante",
    "Guia": "rol_guia",
    "Comercio": "rol_comercio",
    "Ente": "rol_ente_publico",
    "Admin": "rol_admin_rutas",
}
SESSION_SECONDS = 8 * 60 * 60
bearer = HTTPBearer(auto_error=False)


def session_secret():
    value = os.environ.get("M3_SESSION_SECRET", "").encode()
    if len(value) < 32:
        raise HTTPException(503, "Configura M3_SESSION_SECRET con al menos 32 caracteres.")
    return value


def perfil_web(row):
    rif_admin = os.environ.get("M3_ADMIN_RIF", "").strip()
    return "Admin" if rif_admin and row["tipo_actor"] == "Ente" and row["identificador"] == rif_admin else row["tipo_actor"]


def credential_version(password_hash, secret):
    return hmac.digest(secret, b"credencial:" + password_hash.encode(), hashlib.sha256).hex()


def create_token(user_id, password_hash):
    secret = session_secret()
    payload = json.dumps({"sub": user_id, "exp": int(time.time()) + SESSION_SECONDS,
                          "version": credential_version(password_hash, secret)}, separators=(",", ":"))
    encoded = base64.urlsafe_b64encode(payload.encode()).decode()
    digest = hmac.digest(secret, encoded.encode(), hashlib.sha256).hex()
    return f"{encoded}.{digest}"


def perfil_actual(authorization: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]):
    invalid = HTTPException(401, "Inicia sesión para continuar.", headers={"WWW-Authenticate": "Bearer"})
    if authorization is None:
        raise invalid
    secret = session_secret()
    try:
        encoded, digest = authorization.credentials.split(".", 1)
        expected = hmac.digest(secret, encoded.encode(), hashlib.sha256).hex()
        if not hmac.compare_digest(expected, digest):
            raise invalid
        payload = json.loads(base64.urlsafe_b64decode(encoded))
        user_id = payload["sub"]
        version = payload["version"]
        if not isinstance(user_id, int) or not isinstance(version, str) or payload["exp"] <= time.time():
            raise invalid
    except (ValueError, KeyError, TypeError) as exc:
        raise invalid from exc
    with transaction("rol_m3_autenticacion") as cur:
        cur.execute("""SELECT id_usuario, tipo_actor, identificador, nombre, contrasena_hash
            FROM VW_M3_AUTH WHERE id_usuario = %s""", (user_id,))
        row = cur.fetchone()
    if row is None or not hmac.compare_digest(version, credential_version(row["contrasena_hash"], secret)):
        raise invalid
    return {"id_usuario": user_id, "tipo_actor": row["tipo_actor"], "perfil": perfil_web(row), "nombre": row["nombre"]}


Profile = Annotated[dict, Depends(perfil_actual)]


def write_roles(*roles):
    def validate(profile: Profile):
        if profile["perfil"] not in roles:
            raise HTTPException(403, "Tu perfil no puede realizar esta operación.")
        return profile
    return validate


def get_db(profile: Profile):
    with transaction(ROLES[profile["perfil"]], profile["id_usuario"]) as cur:
        yield cur


Database = Annotated[object, Depends(get_db, scope="function")]


def pagination(
    page: Annotated[int, Query(ge=1, le=10_000_000)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 10,
    sort_by: Annotated[str | None, Query(max_length=60)] = None,
    sort_dir: Literal["asc", "desc"] = "asc",
):
    return page, page_size, sort_by, sort_dir


Pagination = Annotated[tuple, Depends(pagination)]
