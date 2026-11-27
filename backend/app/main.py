"""
============================================================================
Archivo: backend/app/main.py
Módulo: Base común (Paso 0 - Contratos Congelados)
Descripción: Punto de entrada FastAPI, endpoint de diagnóstico /api/health,
             registro modular de routers (M1 activo y ganchos opcionales para
             M2/M3 sin conflictos) y servidor de archivos estáticos Frontend.
============================================================================
"""
from __future__ import annotations

import importlib
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.db import REPO_ROOT, get_db_cursor
from app.routers import m1_patrimonio

app = FastAPI(
    title="Rutas Venezuela API",
    description="API REST en SQL puro (psycopg2) para la Segunda Entrega de Bases de Datos - UCAB",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health", tags=["Sistema"])
def health_check():
    """Verifica conectividad en vivo contra el contenedor PostgreSQL."""
    with get_db_cursor() as cur:
        cur.execute("SELECT current_database() AS db, current_user AS usr;")
        meta = cur.fetchone()
        cur.execute("SELECT to_regclass('public.hito_turistico') AS existe_hito;")
        existe = cur.fetchone()["existe_hito"]
        hitos_count = 0
        if existe is not None:
            cur.execute("SELECT COUNT(*) AS total FROM Hito_Turistico;")
            hitos_count = int(cur.fetchone()["total"])
    return {
        "status": "ok",
        "database": meta["db"],
        "user": meta["usr"],
        "hitos_registrados": hitos_count,
        "modulos_activos": {
            "m1_patrimonio": True,
            "m2_infraestructura": "app.routers.m2_infraestructura" in LOADED_OPTIONAL_MODULES,
            "m3_transacciones": "app.routers.m3_transacciones" in LOADED_OPTIONAL_MODULES,
        },
    }


# Registro obligatorio del Módulo 1 (José Alejandro Montes de Oca Tineo)
app.include_router(m1_patrimonio.router)

LOADED_OPTIONAL_MODULES: set[str] = set()

# Ganchos opcionales para integración paralela sin conflictos (M2 Andrea / M3 Leonardo)
for optional_mod in (
    "app.routers.auth",
    "app.routers.m2_infraestructura",
    "app.routers.m3_transacciones",
):
    try:
        mod = importlib.import_module(optional_mod)
        if hasattr(mod, "router"):
            app.include_router(mod.router)
            LOADED_OPTIONAL_MODULES.add(optional_mod)
    except ModuleNotFoundError:
        pass

FRONTEND_DIR: Path = REPO_ROOT / "frontend"
if FRONTEND_DIR.exists():
    app.mount("/", StaticFiles(directory=str(FRONTEND_DIR), html=True), name="frontend")
