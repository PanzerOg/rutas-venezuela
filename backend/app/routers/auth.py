# Módulo 3 · Autor responsable: Leonardo Enrique Chacón Agraz - C.I. 31.895.402
import hashlib
import hmac
import secrets
from typing import Literal

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field, SecretStr

from ..m3_db import transaction
from ..m3_deps import Profile, create_token, perfil_web

router = APIRouter(prefix="/api/auth", tags=["Autenticación"])
ITERATIONS = 600_000
DUMMY_HASH = "pbkdf2_sha256:600000:00000000000000000000000000000000:" + "00" * 32


def hash_password(password):
    salt = secrets.token_bytes(16)
    encoded = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, ITERATIONS)
    return f"pbkdf2_sha256:{ITERATIONS}:{salt.hex()}:{encoded.hex()}"


def verify_password(password, value):
    try:
        scheme, rounds, salt, digest = value.split(":")
        if scheme != "pbkdf2_sha256" or not 100_000 <= int(rounds) <= 2_000_000:
            return False
        check = hashlib.pbkdf2_hmac("sha256", password.encode(), bytes.fromhex(salt), int(rounds))
        return hmac.compare_digest(check, bytes.fromhex(digest))
    except ValueError:
        return False


class Login(BaseModel):
    tipo_actor: Literal["Visitante", "Guia", "Comercio", "Ente"]
    identificador: str = Field(min_length=1, max_length=40)
    complemento: str | None = Field(default=None, max_length=40)
    contrasena: SecretStr = Field(min_length=1, max_length=128)


@router.post("/login")
def login(body: Login):
    identificador = body.identificador.strip()
    complemento = body.complemento.strip() if body.complemento else None
    with transaction("rol_m3_autenticacion") as cur:
        cur.execute(
            """SELECT id_usuario, tipo_actor, identificador, nombre, contrasena_hash
               FROM VW_M3_AUTH
               WHERE tipo_actor = %s AND identificador = %s AND complemento IS NOT DISTINCT FROM %s""",
            (body.tipo_actor, identificador, complemento),
        )
        row = cur.fetchone()
    if not verify_password(body.contrasena.get_secret_value(), row["contrasena_hash"] if row else DUMMY_HASH) or row is None:
        raise HTTPException(401, "Identificador o contraseña incorrectos.")
    return {"access_token": create_token(row["id_usuario"], row["contrasena_hash"]), "token_type": "bearer",
            "usuario": {"id_usuario": row["id_usuario"], "tipo_actor": row["tipo_actor"],
                        "perfil": perfil_web(row), "nombre": row["nombre"]}}


@router.get("/me")
def me(profile: Profile):
    return profile
