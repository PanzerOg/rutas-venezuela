"""
============================================================================
Archivo: backend/app/routers/m1_patrimonio.py
Módulo: Módulo 1 - Territorio, Hitos Turísticos y Realidad Aumentada
Autor responsable: José Alejandro Montes de Oca Tineo - C.I. 31.066.053
Descripción: Endpoints REST para RF-CRUD-01..04, RF-VA-01, Consultas 1, 2 y 5,
             y Reporte Estratégico M1 usando exclusivamente SQL puro (psycopg2)
             y rutinas PL/pgSQL. Cero ORM y cero subconsultas en SELECT/FROM.
============================================================================
"""
from __future__ import annotations

import csv
import io
from datetime import datetime, time
from typing import Literal

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from app.db import get_db_cursor, paginate_query, serialize_row, serialize_rows

router = APIRouter(
    prefix="/api/m1",
    tags=["Módulo 1 - Patrimonio, Territorio y RA"],
)


# ============================================================================
# ESQUEMAS PYDANTIC DE ENTRADA
# ============================================================================


class EstadoCreate(BaseModel):
    cod_estado: str = Field(..., min_length=1, max_length=6)
    nombre_estado: str = Field(..., min_length=1, max_length=100)


class EstadoUpdate(BaseModel):
    nombre_estado: str = Field(..., min_length=1, max_length=100)


class MunicipioCreate(BaseModel):
    cod_estado: str = Field(..., min_length=1, max_length=6)
    cod_municipio: str = Field(..., min_length=1, max_length=10)
    nombre_municipio: str = Field(..., min_length=1, max_length=120)


class MunicipioUpdate(BaseModel):
    nombre_municipio: str = Field(..., min_length=1, max_length=120)


class ParroquiaCreate(BaseModel):
    cod_estado: str = Field(..., min_length=1, max_length=6)
    cod_municipio: str = Field(..., min_length=1, max_length=10)
    cod_parroquia: str = Field(..., min_length=1, max_length=10)
    nombre_parroquia: str = Field(..., min_length=1, max_length=120)
    tipo_demarcacion: Literal["Urbana", "Rural", "Mixta"]


class ParroquiaUpdate(BaseModel):
    nombre_parroquia: str = Field(..., min_length=1, max_length=120)
    tipo_demarcacion: Literal["Urbana", "Rural", "Mixta"]


class CategoriaCreate(BaseModel):
    nombre_categoria: str = Field(..., min_length=1, max_length=100)
    descripcion: str = Field(..., min_length=1)


class HitoCreate(BaseModel):
    cod_estado: str = Field(..., min_length=1, max_length=6)
    cod_municipio: str = Field(..., min_length=1, max_length=10)
    cod_parroquia: str = Field(..., min_length=1, max_length=10)
    nombre_hito: str = Field(..., min_length=1, max_length=150)
    descripcion: str = Field(..., min_length=1)
    estado_operativo: Literal[
        "Disponible",
        "En restauracion",
        "Clausurado temporalmente",
        "Cerrado permanentemente",
    ]
    libre_acceso: bool
    estado_conservacion: Literal["Optimo", "Bueno", "Regular", "Deteriorado", "Critico"]
    latitud: float = Field(..., ge=-90, le=90)
    longitud: float = Field(..., ge=-180, le=180)
    elevacion: float = Field(..., ge=0)
    categorias: list[int] = Field(..., min_length=1)
    dia_semana: Literal[
        "Lunes", "Martes", "Miercoles", "Jueves", "Viernes", "Sabado", "Domingo"
    ] | None = None
    hora_apertura: time | None = None
    hora_cierre: time | None = None


class HitoUpdate(BaseModel):
    cod_estado: str = Field(..., min_length=1, max_length=6)
    cod_municipio: str = Field(..., min_length=1, max_length=10)
    cod_parroquia: str = Field(..., min_length=1, max_length=10)
    nombre_hito: str = Field(..., min_length=1, max_length=150)
    descripcion: str = Field(..., min_length=1)
    estado_operativo: Literal[
        "Disponible",
        "En restauracion",
        "Clausurado temporalmente",
        "Cerrado permanentemente",
    ]
    libre_acceso: bool
    estado_conservacion: Literal["Optimo", "Bueno", "Regular", "Deteriorado", "Critico"]
    latitud: float = Field(..., ge=-90, le=90)
    longitud: float = Field(..., ge=-180, le=180)
    elevacion: float = Field(..., ge=0)


class HitoCategoriaLink(BaseModel):
    cod_estado: str
    cod_municipio: str
    cod_parroquia: str
    nombre_hito: str
    id_categoria: int


class Recurso3DCreate(BaseModel):
    cod_recurso_3d: str = Field(..., min_length=1, max_length=40)
    tipo_recurso: Literal[
        "Modelo 3D",
        "Reconstruccion Historica",
        "Guia Flotante",
        "Audiovisual Interactivo",
    ]
    descripcion: str = Field(..., min_length=1)


class Recurso3DUpdate(BaseModel):
    tipo_recurso: Literal[
        "Modelo 3D",
        "Reconstruccion Historica",
        "Guia Flotante",
        "Audiovisual Interactivo",
    ]
    descripcion: str = Field(..., min_length=1)


class AnclajeRACreate(BaseModel):
    cod_recurso_3d: str = Field(..., min_length=1, max_length=40)
    cod_estado: str = Field(..., min_length=1, max_length=6)
    cod_municipio: str = Field(..., min_length=1, max_length=10)
    cod_parroquia: str = Field(..., min_length=1, max_length=10)
    nombre_hito: str = Field(..., min_length=1, max_length=150)
    latitud: float = Field(..., ge=-90, le=90)
    longitud: float = Field(..., ge=-180, le=180)
    altitud_suelo: float = Field(..., ge=0)
    azimut: float = Field(..., ge=0, lt=360)
    inclinacion: float = Field(..., ge=-90, le=90)
    rotacion: float = Field(..., ge=0, lt=360)
    radio_activacion_m: float = Field(..., gt=0)
    escala: float = Field(..., gt=0)
    hipervinculo_info: str = Field(..., min_length=1, max_length=300)


class HorarioCreate(BaseModel):
    cod_estado: str = Field(..., min_length=1, max_length=6)
    cod_municipio: str = Field(..., min_length=1, max_length=10)
    cod_parroquia: str = Field(..., min_length=1, max_length=10)
    nombre_hito: str = Field(..., min_length=1, max_length=150)
    dia_semana: Literal[
        "Lunes", "Martes", "Miercoles", "Jueves", "Viernes", "Sabado", "Domingo"
    ]
    hora_apertura: time
    hora_cierre: time


class HorarioUpdate(BaseModel):
    cod_estado: str
    cod_municipio: str
    cod_parroquia: str
    nombre_hito: str
    dia_semana: Literal[
        "Lunes", "Martes", "Miercoles", "Jueves", "Viernes", "Sabado", "Domingo"
    ]
    hora_apertura_actual: time
    hora_apertura_nueva: time | None = None
    hora_cierre: time


class EventoCreate(BaseModel):
    titulo: str = Field(..., min_length=1, max_length=160)
    descripcion: str = Field(..., min_length=1)
    tipo_evento: str = Field(..., min_length=1, max_length=60)
    fecha_inicio: datetime
    fecha_fin: datetime
    cod_estado: str | None = None
    cod_municipio: str | None = None
    cod_parroquia: str | None = None
    nombre_hito: str | None = None


class EventoUpdate(BaseModel):
    titulo: str = Field(..., min_length=1, max_length=160)
    descripcion: str = Field(..., min_length=1)
    tipo_evento: str = Field(..., min_length=1, max_length=60)
    fecha_inicio: datetime
    fecha_fin: datetime


class SedeEventoCreate(BaseModel):
    cod_estado: str
    cod_municipio: str
    cod_parroquia: str
    nombre_hito: str


# ============================================================================
# HELPER DE FILTROS COMUNES
# ============================================================================


def _build_where(clauses: list[str]) -> str:
    return (" WHERE " + " AND ".join(clauses)) if clauses else ""


# ============================================================================
# 1. RF-CRUD-01: TERRITORIO JERÁRQUICO (ESTADO -> MUNICIPIO -> PARROQUIA)
# ============================================================================


@router.get("/estados")
def list_estados(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: str | None = None,
    sort_dir: str = "asc",
    q: str | None = None,
):
    clauses: list[str] = []
    params: dict[str, object] = {}
    if q and q.strip():
        clauses.append("(e.cod_estado ILIKE %(q)s OR e.nombre_estado ILIKE %(q)s)")
        params["q"] = f"%{q.strip()}%"

    allowed_sort = {
        "cod_estado": "e.cod_estado",
        "nombre_estado": "e.nombre_estado",
    }
    with get_db_cursor() as cur:
        return paginate_query(
            cur=cur,
            base_from_where="Estado e" + _build_where(clauses),
            select_cols="e.cod_estado, e.nombre_estado",
            params=params,
            sort_by=sort_by,
            sort_dir=sort_dir,
            allowed_sort=allowed_sort,
            default_sort="nombre_estado",
            page=page,
            page_size=page_size,
        )


@router.post("/estados", status_code=201)
def create_estado(payload: EstadoCreate):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            INSERT INTO Estado (cod_estado, nombre_estado)
            VALUES (%(cod_estado)s, %(nombre_estado)s)
            RETURNING cod_estado, nombre_estado;
            """,
            {
                "cod_estado": payload.cod_estado.strip().upper(),
                "nombre_estado": payload.nombre_estado.strip(),
            },
        )
        return serialize_row(cur.fetchone())


@router.put("/estados/{cod_estado}")
def update_estado(cod_estado: str, payload: EstadoUpdate):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            UPDATE Estado
            SET nombre_estado = %(nombre_estado)s
            WHERE cod_estado = %(cod_estado)s
            RETURNING cod_estado, nombre_estado;
            """,
            {
                "cod_estado": cod_estado.strip(),
                "nombre_estado": payload.nombre_estado.strip(),
            },
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail=f"Estado '{cod_estado}' no encontrado.")
        return serialize_row(row)


@router.delete("/estados/{cod_estado}")
def delete_estado(cod_estado: str):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            "DELETE FROM Estado WHERE cod_estado = %(cod_estado)s RETURNING cod_estado;",
            {"cod_estado": cod_estado.strip()},
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail=f"Estado '{cod_estado}' no encontrado.")
        return {"deleted": True, "cod_estado": row["cod_estado"]}


@router.get("/municipios")
def list_municipios(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: str | None = None,
    sort_dir: str = "asc",
    cod_estado: str | None = None,
    q: str | None = None,
):
    clauses: list[str] = []
    params: dict[str, object] = {}
    if cod_estado and cod_estado.strip():
        clauses.append("m.cod_estado = %(cod_estado)s")
        params["cod_estado"] = cod_estado.strip()
    if q and q.strip():
        clauses.append(
            "(m.cod_municipio ILIKE %(q)s OR m.nombre_municipio ILIKE %(q)s OR e.nombre_estado ILIKE %(q)s)"
        )
        params["q"] = f"%{q.strip()}%"

    base = "Municipio m JOIN Estado e ON e.cod_estado = m.cod_estado" + _build_where(clauses)
    allowed_sort = {
        "cod_estado": "m.cod_estado",
        "nombre_estado": "e.nombre_estado",
        "cod_municipio": "m.cod_municipio",
        "nombre_municipio": "m.nombre_municipio",
    }
    with get_db_cursor() as cur:
        return paginate_query(
            cur=cur,
            base_from_where=base,
            select_cols="m.cod_estado, e.nombre_estado, m.cod_municipio, m.nombre_municipio",
            params=params,
            sort_by=sort_by,
            sort_dir=sort_dir,
            allowed_sort=allowed_sort,
            default_sort="nombre_estado",
            page=page,
            page_size=page_size,
        )


@router.post("/municipios", status_code=201)
def create_municipio(payload: MunicipioCreate):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            INSERT INTO Municipio (cod_estado, cod_municipio, nombre_municipio)
            VALUES (%(cod_estado)s, %(cod_municipio)s, %(nombre_municipio)s)
            RETURNING cod_estado, cod_municipio, nombre_municipio;
            """,
            {
                "cod_estado": payload.cod_estado.strip().upper(),
                "cod_municipio": payload.cod_municipio.strip().upper(),
                "nombre_municipio": payload.nombre_municipio.strip(),
            },
        )
        return serialize_row(cur.fetchone())


@router.put("/municipios/{cod_estado}/{cod_municipio}")
def update_municipio(cod_estado: str, cod_municipio: str, payload: MunicipioUpdate):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            UPDATE Municipio
            SET nombre_municipio = %(nombre_municipio)s
            WHERE cod_estado = %(cod_estado)s AND cod_municipio = %(cod_municipio)s
            RETURNING cod_estado, cod_municipio, nombre_municipio;
            """,
            {
                "cod_estado": cod_estado.strip(),
                "cod_municipio": cod_municipio.strip(),
                "nombre_municipio": payload.nombre_municipio.strip(),
            },
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(
                status_code=404,
                detail=f"Municipio '{cod_estado}/{cod_municipio}' no encontrado.",
            )
        return serialize_row(row)


@router.delete("/municipios/{cod_estado}/{cod_municipio}")
def delete_municipio(cod_estado: str, cod_municipio: str):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            DELETE FROM Municipio
            WHERE cod_estado = %(cod_estado)s AND cod_municipio = %(cod_municipio)s
            RETURNING cod_estado, cod_municipio;
            """,
            {"cod_estado": cod_estado.strip(), "cod_municipio": cod_municipio.strip()},
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(
                status_code=404,
                detail=f"Municipio '{cod_estado}/{cod_municipio}' no encontrado.",
            )
        return {"deleted": True, "cod_estado": row["cod_estado"], "cod_municipio": row["cod_municipio"]}


@router.get("/parroquias")
def list_parroquias(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: str | None = None,
    sort_dir: str = "asc",
    cod_estado: str | None = None,
    cod_municipio: str | None = None,
    tipo_demarcacion: str | None = None,
    q: str | None = None,
):
    clauses: list[str] = []
    params: dict[str, object] = {}
    if cod_estado and cod_estado.strip():
        clauses.append("p.cod_estado = %(cod_estado)s")
        params["cod_estado"] = cod_estado.strip()
    if cod_municipio and cod_municipio.strip():
        clauses.append("p.cod_municipio = %(cod_municipio)s")
        params["cod_municipio"] = cod_municipio.strip()
    if tipo_demarcacion and tipo_demarcacion.strip():
        clauses.append("p.tipo_demarcacion = %(tipo_demarcacion)s")
        params["tipo_demarcacion"] = tipo_demarcacion.strip()
    if q and q.strip():
        clauses.append(
            "(p.cod_parroquia ILIKE %(q)s OR p.nombre_parroquia ILIKE %(q)s "
            "OR m.nombre_municipio ILIKE %(q)s OR e.nombre_estado ILIKE %(q)s)"
        )
        params["q"] = f"%{q.strip()}%"

    base = (
        "Parroquia p "
        "JOIN Municipio m ON m.cod_estado = p.cod_estado AND m.cod_municipio = p.cod_municipio "
        "JOIN Estado e ON e.cod_estado = m.cod_estado" + _build_where(clauses)
    )
    allowed_sort = {
        "nombre_estado": "e.nombre_estado",
        "nombre_municipio": "m.nombre_municipio",
        "cod_parroquia": "p.cod_parroquia",
        "nombre_parroquia": "p.nombre_parroquia",
        "tipo_demarcacion": "p.tipo_demarcacion",
    }
    with get_db_cursor() as cur:
        return paginate_query(
            cur=cur,
            base_from_where=base,
            select_cols=(
                "p.cod_estado, e.nombre_estado, p.cod_municipio, m.nombre_municipio, "
                "p.cod_parroquia, p.nombre_parroquia, p.tipo_demarcacion"
            ),
            params=params,
            sort_by=sort_by,
            sort_dir=sort_dir,
            allowed_sort=allowed_sort,
            default_sort="nombre_parroquia",
            page=page,
            page_size=page_size,
        )


@router.post("/parroquias", status_code=201)
def create_parroquia(payload: ParroquiaCreate):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            INSERT INTO Parroquia (cod_estado, cod_municipio, cod_parroquia, nombre_parroquia, tipo_demarcacion)
            VALUES (%(cod_estado)s, %(cod_municipio)s, %(cod_parroquia)s, %(nombre_parroquia)s, %(tipo_demarcacion)s)
            RETURNING cod_estado, cod_municipio, cod_parroquia, nombre_parroquia, tipo_demarcacion;
            """,
            {
                "cod_estado": payload.cod_estado.strip().upper(),
                "cod_municipio": payload.cod_municipio.strip().upper(),
                "cod_parroquia": payload.cod_parroquia.strip().upper(),
                "nombre_parroquia": payload.nombre_parroquia.strip(),
                "tipo_demarcacion": payload.tipo_demarcacion,
            },
        )
        return serialize_row(cur.fetchone())


@router.put("/parroquias/{cod_estado}/{cod_municipio}/{cod_parroquia}")
def update_parroquia(cod_estado: str, cod_municipio: str, cod_parroquia: str, payload: ParroquiaUpdate):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            UPDATE Parroquia
            SET nombre_parroquia = %(nombre_parroquia)s,
                tipo_demarcacion = %(tipo_demarcacion)s
            WHERE cod_estado = %(cod_estado)s
              AND cod_municipio = %(cod_municipio)s
              AND cod_parroquia = %(cod_parroquia)s
            RETURNING cod_estado, cod_municipio, cod_parroquia, nombre_parroquia, tipo_demarcacion;
            """,
            {
                "cod_estado": cod_estado.strip(),
                "cod_municipio": cod_municipio.strip(),
                "cod_parroquia": cod_parroquia.strip(),
                "nombre_parroquia": payload.nombre_parroquia.strip(),
                "tipo_demarcacion": payload.tipo_demarcacion,
            },
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(
                status_code=404,
                detail=f"Parroquia '{cod_estado}/{cod_municipio}/{cod_parroquia}' no encontrada.",
            )
        return serialize_row(row)


@router.delete("/parroquias/{cod_estado}/{cod_municipio}/{cod_parroquia}")
def delete_parroquia(cod_estado: str, cod_municipio: str, cod_parroquia: str):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            DELETE FROM Parroquia
            WHERE cod_estado = %(cod_estado)s
              AND cod_municipio = %(cod_municipio)s
              AND cod_parroquia = %(cod_parroquia)s
            RETURNING cod_parroquia;
            """,
            {
                "cod_estado": cod_estado.strip(),
                "cod_municipio": cod_municipio.strip(),
                "cod_parroquia": cod_parroquia.strip(),
            },
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(
                status_code=404,
                detail=f"Parroquia '{cod_estado}/{cod_municipio}/{cod_parroquia}' no encontrada.",
            )
        return {"deleted": True, "cod_parroquia": row["cod_parroquia"]}


# ============================================================================
# 2. RF-CRUD-02: CATEGORÍAS Y HITOS TURÍSTICOS (FICHA INTEGRAL)
# ============================================================================


@router.get("/categorias")
def list_categorias(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    sort_by: str | None = None,
    sort_dir: str = "asc",
    q: str | None = None,
):
    clauses: list[str] = []
    params: dict[str, object] = {}
    if q and q.strip():
        clauses.append("(c.nombre_categoria ILIKE %(q)s OR c.descripcion ILIKE %(q)s)")
        params["q"] = f"%{q.strip()}%"

    allowed_sort = {
        "id_categoria": "c.id_categoria",
        "nombre_categoria": "c.nombre_categoria",
    }
    with get_db_cursor() as cur:
        return paginate_query(
            cur=cur,
            base_from_where="Categoria c" + _build_where(clauses),
            select_cols="c.id_categoria, c.nombre_categoria, c.descripcion",
            params=params,
            sort_by=sort_by,
            sort_dir=sort_dir,
            allowed_sort=allowed_sort,
            default_sort="id_categoria",
            page=page,
            page_size=page_size,
        )


@router.post("/categorias", status_code=201)
def create_categoria(payload: CategoriaCreate):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            INSERT INTO Categoria (nombre_categoria, descripcion)
            VALUES (%(nombre_categoria)s, %(descripcion)s)
            RETURNING id_categoria, nombre_categoria, descripcion;
            """,
            {
                "nombre_categoria": payload.nombre_categoria.strip(),
                "descripcion": payload.descripcion.strip(),
            },
        )
        return serialize_row(cur.fetchone())


@router.put("/categorias/{id_categoria}")
def update_categoria(id_categoria: int, payload: CategoriaCreate):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            UPDATE Categoria
            SET nombre_categoria = %(nombre_categoria)s,
                descripcion = %(descripcion)s
            WHERE id_categoria = %(id_categoria)s
            RETURNING id_categoria, nombre_categoria, descripcion;
            """,
            {
                "id_categoria": id_categoria,
                "nombre_categoria": payload.nombre_categoria.strip(),
                "descripcion": payload.descripcion.strip(),
            },
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail=f"Categoría {id_categoria} no encontrada.")
        return serialize_row(row)


@router.delete("/categorias/{id_categoria}")
def delete_categoria(id_categoria: int):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            "DELETE FROM Categoria WHERE id_categoria = %(id_categoria)s RETURNING id_categoria;",
            {"id_categoria": id_categoria},
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail=f"Categoría {id_categoria} no encontrada.")
        return {"deleted": True, "id_categoria": row["id_categoria"]}


@router.get("/hitos")
def list_hitos(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: str | None = None,
    sort_dir: str = "asc",
    cod_estado: str | None = None,
    cod_municipio: str | None = None,
    cod_parroquia: str | None = None,
    estado_operativo: str | None = None,
    estado_conservacion: str | None = None,
    libre_acceso: bool | None = None,
    id_categoria: int | None = None,
    q: str | None = None,
):
    from_sql = "VW_M1_FICHA_HITO h"
    clauses: list[str] = []
    params: dict[str, object] = {}

    if id_categoria is not None:
        from_sql += (
            " JOIN Hito_Categoria hc ON hc.cod_estado = h.cod_estado "
            "AND hc.cod_municipio = h.cod_municipio "
            "AND hc.cod_parroquia = h.cod_parroquia "
            "AND hc.nombre_hito = h.nombre_hito"
        )
        clauses.append("hc.id_categoria = %(id_categoria)s")
        params["id_categoria"] = id_categoria

    if cod_estado and cod_estado.strip():
        clauses.append("h.cod_estado = %(cod_estado)s")
        params["cod_estado"] = cod_estado.strip()
    if cod_municipio and cod_municipio.strip():
        clauses.append("h.cod_municipio = %(cod_municipio)s")
        params["cod_municipio"] = cod_municipio.strip()
    if cod_parroquia and cod_parroquia.strip():
        clauses.append("h.cod_parroquia = %(cod_parroquia)s")
        params["cod_parroquia"] = cod_parroquia.strip()
    if estado_operativo and estado_operativo.strip():
        clauses.append("h.estado_operativo = %(estado_operativo)s")
        params["estado_operativo"] = estado_operativo.strip()
    if estado_conservacion and estado_conservacion.strip():
        clauses.append("h.estado_conservacion = %(estado_conservacion)s")
        params["estado_conservacion"] = estado_conservacion.strip()
    if libre_acceso is not None:
        clauses.append("h.libre_acceso = %(libre_acceso)s")
        params["libre_acceso"] = libre_acceso
    if q and q.strip():
        clauses.append(
            "(h.nombre_hito ILIKE %(q)s OR h.descripcion ILIKE %(q)s "
            "OR h.nombre_estado ILIKE %(q)s OR h.nombre_municipio ILIKE %(q)s "
            "OR h.nombre_parroquia ILIKE %(q)s OR h.categorias_lista ILIKE %(q)s)"
        )
        params["q"] = f"%{q.strip()}%"

    allowed_sort = {
        "nombre_hito": "h.nombre_hito",
        "nombre_estado": "h.nombre_estado",
        "nombre_municipio": "h.nombre_municipio",
        "nombre_parroquia": "h.nombre_parroquia",
        "estado_operativo": "h.estado_operativo",
        "estado_conservacion": "h.estado_conservacion",
        "libre_acceso": "h.libre_acceso",
        "elevacion": "h.elevacion",
        "total_anclajes_ra": "h.total_anclajes_ra",
        "total_eventos": "h.total_eventos",
    }
    with get_db_cursor() as cur:
        return paginate_query(
            cur=cur,
            base_from_where=from_sql + _build_where(clauses),
            select_cols="h.*",
            params=params,
            sort_by=sort_by,
            sort_dir=sort_dir,
            allowed_sort=allowed_sort,
            default_sort="nombre_hito",
            page=page,
            page_size=page_size,
        )


@router.get("/hitos/detalle")
def get_hito_detalle(
    cod_estado: str = Query(...),
    cod_municipio: str = Query(...),
    cod_parroquia: str = Query(...),
    nombre_hito: str = Query(...),
):
    pk = {
        "cod_estado": cod_estado.strip(),
        "cod_municipio": cod_municipio.strip(),
        "cod_parroquia": cod_parroquia.strip(),
        "nombre_hito": nombre_hito.strip(),
    }
    with get_db_cursor() as cur:
        cur.execute(
            """
            SELECT * FROM VW_M1_FICHA_HITO
            WHERE cod_estado = %(cod_estado)s
              AND cod_municipio = %(cod_municipio)s
              AND cod_parroquia = %(cod_parroquia)s
              AND nombre_hito = %(nombre_hito)s;
            """,
            pk,
        )
        ficha = serialize_row(cur.fetchone())
        if not ficha:
            raise HTTPException(status_code=404, detail="Hito turístico no encontrado.")

        cur.execute(
            """
            SELECT c.id_categoria, c.nombre_categoria, c.descripcion
            FROM Hito_Categoria hc
            JOIN Categoria c ON c.id_categoria = hc.id_categoria
            WHERE hc.cod_estado = %(cod_estado)s
              AND hc.cod_municipio = %(cod_municipio)s
              AND hc.cod_parroquia = %(cod_parroquia)s
              AND hc.nombre_hito = %(nombre_hito)s
            ORDER BY c.nombre_categoria;
            """,
            pk,
        )
        categorias = serialize_rows(cur.fetchall())

        cur.execute(
            """
            SELECT dia_semana, hora_apertura, hora_cierre
            FROM Horario_Hito
            WHERE cod_estado = %(cod_estado)s
              AND cod_municipio = %(cod_municipio)s
              AND cod_parroquia = %(cod_parroquia)s
              AND nombre_hito = %(nombre_hito)s
            ORDER BY
                CASE dia_semana
                    WHEN 'Lunes' THEN 1 WHEN 'Martes' THEN 2 WHEN 'Miercoles' THEN 3
                    WHEN 'Jueves' THEN 4 WHEN 'Viernes' THEN 5 WHEN 'Sabado' THEN 6 ELSE 7
                END,
                hora_apertura;
            """,
            pk,
        )
        horarios = serialize_rows(cur.fetchall())

        cur.execute(
            """
            SELECT ev.id_evento, ev.titulo, ev.descripcion, ev.tipo_evento, ev.fecha_inicio, ev.fecha_fin
            FROM Sede_De_Evento se
            JOIN Evento_Actividad ev ON ev.id_evento = se.id_evento
            WHERE se.cod_estado = %(cod_estado)s
              AND se.cod_municipio = %(cod_municipio)s
              AND se.cod_parroquia = %(cod_parroquia)s
              AND se.nombre_hito = %(nombre_hito)s
            ORDER BY ev.fecha_inicio DESC;
            """,
            pk,
        )
        eventos = serialize_rows(cur.fetchall())

        cur.execute(
            """
            SELECT *
            FROM VW_M1_ANCLAJES_RA_CATALOGO
            WHERE cod_estado = %(cod_estado)s
              AND cod_municipio = %(cod_municipio)s
              AND cod_parroquia = %(cod_parroquia)s
              AND nombre_hito = %(nombre_hito)s
            ORDER BY id_anclaje;
            """,
            pk,
        )
        anclajes_ra = serialize_rows(cur.fetchall())

        rutas_m2: list[dict] = []
        cur.execute(
            "SELECT to_regclass('public.itinerario_paso') AS reg_paso, to_regclass('public.ruta') AS reg_ruta;"
        )
        reg = cur.fetchone()
        if reg["reg_paso"] is not None and reg["reg_ruta"] is not None:
            cur.execute(
                """
                SELECT r.id_ruta, r.nombre_ruta, ip.orden_secuencia
                FROM Itinerario_Paso ip
                JOIN Ruta r ON r.id_ruta = ip.id_ruta
                WHERE ip.id_punto_itin = %(id_punto_itin)s
                ORDER BY r.nombre_ruta, ip.orden_secuencia;
                """,
                {"id_punto_itin": ficha["id_punto_itin"]},
            )
            rutas_m2 = serialize_rows(cur.fetchall())

    return {
        "ficha": ficha,
        "categorias": categorias,
        "horarios": horarios,
        "eventos": eventos,
        "anclajes_ra": anclajes_ra,
        "rutas_m2": rutas_m2,
    }


@router.post("/hitos", status_code=201)
def create_hito(payload: HitoCreate):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            CALL SP_REGISTRAR_HITO_COMPLETO(
                %(cod_estado)s,
                %(cod_municipio)s,
                %(cod_parroquia)s,
                %(nombre_hito)s,
                %(descripcion)s,
                %(estado_operativo)s,
                %(libre_acceso)s,
                %(estado_conservacion)s,
                %(latitud)s::NUMERIC,
                %(longitud)s::NUMERIC,
                %(elevacion)s::NUMERIC,
                %(categorias)s::INTEGER[],
                %(dia_semana)s,
                %(hora_apertura)s::TIME,
                %(hora_cierre)s::TIME
            );
            """,
            {
                "cod_estado": payload.cod_estado.strip(),
                "cod_municipio": payload.cod_municipio.strip(),
                "cod_parroquia": payload.cod_parroquia.strip(),
                "nombre_hito": payload.nombre_hito.strip(),
                "descripcion": payload.descripcion.strip(),
                "estado_operativo": payload.estado_operativo,
                "libre_acceso": payload.libre_acceso,
                "estado_conservacion": payload.estado_conservacion,
                "latitud": payload.latitud,
                "longitud": payload.longitud,
                "elevacion": payload.elevacion,
                "categorias": payload.categorias,
                "dia_semana": payload.dia_semana,
                "hora_apertura": payload.hora_apertura,
                "hora_cierre": payload.hora_cierre,
            },
        )
        cur.execute(
            """
            SELECT * FROM VW_M1_FICHA_HITO
            WHERE cod_estado = %(cod_estado)s
              AND cod_municipio = %(cod_municipio)s
              AND cod_parroquia = %(cod_parroquia)s
              AND nombre_hito = %(nombre_hito)s;
            """,
            {
                "cod_estado": payload.cod_estado.strip(),
                "cod_municipio": payload.cod_municipio.strip(),
                "cod_parroquia": payload.cod_parroquia.strip(),
                "nombre_hito": payload.nombre_hito.strip(),
            },
        )
        return serialize_row(cur.fetchone())


@router.put("/hitos")
def update_hito(payload: HitoUpdate):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            UPDATE Hito_Turistico
            SET descripcion = %(descripcion)s,
                estado_operativo = %(estado_operativo)s,
                libre_acceso = %(libre_acceso)s,
                estado_conservacion = %(estado_conservacion)s,
                latitud = %(latitud)s,
                longitud = %(longitud)s,
                elevacion = %(elevacion)s
            WHERE cod_estado = %(cod_estado)s
              AND cod_municipio = %(cod_municipio)s
              AND cod_parroquia = %(cod_parroquia)s
              AND nombre_hito = %(nombre_hito)s
            RETURNING cod_estado, cod_municipio, cod_parroquia, nombre_hito;
            """,
            {
                "cod_estado": payload.cod_estado.strip(),
                "cod_municipio": payload.cod_municipio.strip(),
                "cod_parroquia": payload.cod_parroquia.strip(),
                "nombre_hito": payload.nombre_hito.strip(),
                "descripcion": payload.descripcion.strip(),
                "estado_operativo": payload.estado_operativo,
                "libre_acceso": payload.libre_acceso,
                "estado_conservacion": payload.estado_conservacion,
                "latitud": payload.latitud,
                "longitud": payload.longitud,
                "elevacion": payload.elevacion,
            },
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Hito turístico no encontrado.")
        cur.execute(
            """
            SELECT * FROM VW_M1_FICHA_HITO
            WHERE cod_estado = %(cod_estado)s
              AND cod_municipio = %(cod_municipio)s
              AND cod_parroquia = %(cod_parroquia)s
              AND nombre_hito = %(nombre_hito)s;
            """,
            row,
        )
        return serialize_row(cur.fetchone())


@router.delete("/hitos")
def delete_hito(
    cod_estado: str = Query(...),
    cod_municipio: str = Query(...),
    cod_parroquia: str = Query(...),
    nombre_hito: str = Query(...),
):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            DELETE FROM Hito_Turistico
            WHERE cod_estado = %(cod_estado)s
              AND cod_municipio = %(cod_municipio)s
              AND cod_parroquia = %(cod_parroquia)s
              AND nombre_hito = %(nombre_hito)s
            RETURNING id_punto_itin, id_elem_afectable, id_obj_evaluable, id_elem_servicio;
            """,
            {
                "cod_estado": cod_estado.strip(),
                "cod_municipio": cod_municipio.strip(),
                "cod_parroquia": cod_parroquia.strip(),
                "nombre_hito": nombre_hito.strip(),
            },
        )
        refs = cur.fetchone()
        if not refs:
            raise HTTPException(status_code=404, detail="Hito turístico no encontrado.")

        # Limpieza ordenada de superclases de categoría huérfanas tras borrar Hito_Turistico
        cur.execute("DELETE FROM Punto_Itinerario WHERE id_punto_itin = %s;", (refs["id_punto_itin"],))
        cur.execute("DELETE FROM Elemento_Afectable WHERE id_elem_afectable = %s;", (refs["id_elem_afectable"],))
        cur.execute("DELETE FROM Objeto_Evaluable WHERE id_obj_evaluable = %s;", (refs["id_obj_evaluable"],))
        cur.execute("DELETE FROM Elemento_Servicio WHERE id_elem_servicio = %s;", (refs["id_elem_servicio"],))

    return {"deleted": True, "nombre_hito": nombre_hito}


@router.post("/hitos/categorias", status_code=201)
def add_hito_categoria(payload: HitoCategoriaLink):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            INSERT INTO Hito_Categoria (cod_estado, cod_municipio, cod_parroquia, nombre_hito, id_categoria)
            VALUES (%(cod_estado)s, %(cod_municipio)s, %(cod_parroquia)s, %(nombre_hito)s, %(id_categoria)s)
            RETURNING cod_estado, cod_municipio, cod_parroquia, nombre_hito, id_categoria;
            """,
            payload.model_dump(),
        )
        return serialize_row(cur.fetchone())


@router.delete("/hitos/categorias")
def remove_hito_categoria(
    cod_estado: str = Query(...),
    cod_municipio: str = Query(...),
    cod_parroquia: str = Query(...),
    nombre_hito: str = Query(...),
    id_categoria: int = Query(...),
):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            DELETE FROM Hito_Categoria
            WHERE cod_estado = %(cod_estado)s
              AND cod_municipio = %(cod_municipio)s
              AND cod_parroquia = %(cod_parroquia)s
              AND nombre_hito = %(nombre_hito)s
              AND id_categoria = %(id_categoria)s
            RETURNING id_categoria;
            """,
            {
                "cod_estado": cod_estado.strip(),
                "cod_municipio": cod_municipio.strip(),
                "cod_parroquia": cod_parroquia.strip(),
                "nombre_hito": nombre_hito.strip(),
                "id_categoria": id_categoria,
            },
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Asociación hito-categoría no encontrada.")
        return {"deleted": True, "id_categoria": row["id_categoria"]}


# ============================================================================
# 3. RF-CRUD-03: RECURSOS 3D Y PUNTOS DE ANCLAJE DE REALIDAD AUMENTADA
# ============================================================================


@router.get("/recursos-3d")
def list_recursos_3d(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: str | None = None,
    sort_dir: str = "asc",
    tipo_recurso: str | None = None,
    q: str | None = None,
):
    clauses: list[str] = []
    params: dict[str, object] = {}
    if tipo_recurso and tipo_recurso.strip():
        clauses.append("r.tipo_recurso = %(tipo_recurso)s")
        params["tipo_recurso"] = tipo_recurso.strip()
    if q and q.strip():
        clauses.append(
            "(r.cod_recurso_3d ILIKE %(q)s OR r.tipo_recurso ILIKE %(q)s OR r.descripcion ILIKE %(q)s)"
        )
        params["q"] = f"%{q.strip()}%"

    allowed_sort = {
        "cod_recurso_3d": "r.cod_recurso_3d",
        "tipo_recurso": "r.tipo_recurso",
    }
    with get_db_cursor() as cur:
        return paginate_query(
            cur=cur,
            base_from_where="Recurso_3D r" + _build_where(clauses),
            select_cols="r.cod_recurso_3d, r.tipo_recurso, r.descripcion",
            params=params,
            sort_by=sort_by,
            sort_dir=sort_dir,
            allowed_sort=allowed_sort,
            default_sort="cod_recurso_3d",
            page=page,
            page_size=page_size,
        )


@router.post("/recursos-3d", status_code=201)
def create_recurso_3d(payload: Recurso3DCreate):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            INSERT INTO Recurso_3D (cod_recurso_3d, tipo_recurso, descripcion)
            VALUES (%(cod_recurso_3d)s, %(tipo_recurso)s, %(descripcion)s)
            RETURNING cod_recurso_3d, tipo_recurso, descripcion;
            """,
            {
                "cod_recurso_3d": payload.cod_recurso_3d.strip().upper(),
                "tipo_recurso": payload.tipo_recurso,
                "descripcion": payload.descripcion.strip(),
            },
        )
        return serialize_row(cur.fetchone())


@router.put("/recursos-3d/{cod_recurso_3d}")
def update_recurso_3d(cod_recurso_3d: str, payload: Recurso3DUpdate):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            UPDATE Recurso_3D
            SET tipo_recurso = %(tipo_recurso)s,
                descripcion = %(descripcion)s
            WHERE cod_recurso_3d = %(cod_recurso_3d)s
            RETURNING cod_recurso_3d, tipo_recurso, descripcion;
            """,
            {
                "cod_recurso_3d": cod_recurso_3d.strip(),
                "tipo_recurso": payload.tipo_recurso,
                "descripcion": payload.descripcion.strip(),
            },
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail=f"Recurso 3D '{cod_recurso_3d}' no encontrado.")
        return serialize_row(row)


@router.delete("/recursos-3d/{cod_recurso_3d}")
def delete_recurso_3d(cod_recurso_3d: str):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            "DELETE FROM Recurso_3D WHERE cod_recurso_3d = %(cod)s RETURNING cod_recurso_3d;",
            {"cod": cod_recurso_3d.strip()},
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail=f"Recurso 3D '{cod_recurso_3d}' no encontrado.")
        return {"deleted": True, "cod_recurso_3d": row["cod_recurso_3d"]}


@router.get("/anclajes-ra")
def list_anclajes_ra(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: str | None = None,
    sort_dir: str = "asc",
    cod_estado: str | None = None,
    cod_recurso_3d: str | None = None,
    tipo_recurso: str | None = None,
    nombre_hito: str | None = None,
    q: str | None = None,
):
    clauses: list[str] = []
    params: dict[str, object] = {}
    if cod_estado and cod_estado.strip():
        clauses.append("a.cod_estado = %(cod_estado)s")
        params["cod_estado"] = cod_estado.strip()
    if cod_recurso_3d and cod_recurso_3d.strip():
        clauses.append("a.cod_recurso_3d = %(cod_recurso_3d)s")
        params["cod_recurso_3d"] = cod_recurso_3d.strip()
    if tipo_recurso and tipo_recurso.strip():
        clauses.append("a.tipo_recurso = %(tipo_recurso)s")
        params["tipo_recurso"] = tipo_recurso.strip()
    if nombre_hito and nombre_hito.strip():
        clauses.append("a.nombre_hito = %(nombre_hito)s")
        params["nombre_hito"] = nombre_hito.strip()
    if q and q.strip():
        clauses.append(
            "(a.nombre_hito ILIKE %(q)s OR a.cod_recurso_3d ILIKE %(q)s "
            "OR a.descripcion_recurso ILIKE %(q)s OR a.nombre_estado ILIKE %(q)s)"
        )
        params["q"] = f"%{q.strip()}%"

    allowed_sort = {
        "id_anclaje": "a.id_anclaje",
        "nombre_hito": "a.nombre_hito",
        "nombre_estado": "a.nombre_estado",
        "cod_recurso_3d": "a.cod_recurso_3d",
        "tipo_recurso": "a.tipo_recurso",
        "radio_activacion_m": "a.radio_activacion_m",
        "azimut": "a.azimut",
        "escala": "a.escala",
    }
    with get_db_cursor() as cur:
        return paginate_query(
            cur=cur,
            base_from_where="VW_M1_ANCLAJES_RA_CATALOGO a" + _build_where(clauses),
            select_cols="a.*",
            params=params,
            sort_by=sort_by,
            sort_dir=sort_dir,
            allowed_sort=allowed_sort,
            default_sort="id_anclaje",
            page=page,
            page_size=page_size,
        )


@router.post("/anclajes-ra", status_code=201)
def create_anclaje_ra(payload: AnclajeRACreate):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            CALL SP_CLONAR_RECURSO_ANCLAJE(
                %(cod_recurso_3d)s,
                %(cod_estado)s,
                %(cod_municipio)s,
                %(cod_parroquia)s,
                %(nombre_hito)s,
                %(latitud)s::NUMERIC,
                %(longitud)s::NUMERIC,
                %(altitud_suelo)s::NUMERIC,
                %(azimut)s::NUMERIC,
                %(inclinacion)s::NUMERIC,
                %(rotacion)s::NUMERIC,
                %(radio_activacion_m)s::NUMERIC,
                %(escala)s::NUMERIC,
                %(hipervinculo_info)s,
                NULL
            );
            """,
            payload.model_dump(),
        )
        res = cur.fetchone()
        new_id = res["p_id_anclaje"]
        cur.execute("SELECT * FROM VW_M1_ANCLAJES_RA_CATALOGO WHERE id_anclaje = %s;", (new_id,))
        return serialize_row(cur.fetchone())


@router.put("/anclajes-ra/{id_anclaje}")
def update_anclaje_ra(id_anclaje: int, payload: AnclajeRACreate):
    with get_db_cursor(commit=True) as cur:
        params = payload.model_dump()
        params["id_anclaje"] = id_anclaje
        cur.execute(
            """
            UPDATE Punto_Anclaje_RA
            SET cod_recurso_3d = %(cod_recurso_3d)s,
                cod_estado = %(cod_estado)s,
                cod_municipio = %(cod_municipio)s,
                cod_parroquia = %(cod_parroquia)s,
                nombre_hito = %(nombre_hito)s,
                latitud = %(latitud)s,
                longitud = %(longitud)s,
                altitud_suelo = %(altitud_suelo)s,
                azimut = %(azimut)s,
                inclinacion = %(inclinacion)s,
                rotacion = %(rotacion)s,
                radio_activacion_m = %(radio_activacion_m)s,
                escala = %(escala)s,
                hipervinculo_info = %(hipervinculo_info)s
            WHERE id_anclaje = %(id_anclaje)s
            RETURNING id_anclaje;
            """,
            params,
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail=f"Anclaje RA {id_anclaje} no encontrado.")
        cur.execute("SELECT * FROM VW_M1_ANCLAJES_RA_CATALOGO WHERE id_anclaje = %s;", (id_anclaje,))
        return serialize_row(cur.fetchone())


@router.delete("/anclajes-ra/{id_anclaje}")
def delete_anclaje_ra(id_anclaje: int):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            "DELETE FROM Punto_Anclaje_RA WHERE id_anclaje = %(id)s RETURNING id_anclaje;",
            {"id": id_anclaje},
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail=f"Anclaje RA {id_anclaje} no encontrado.")
        return {"deleted": True, "id_anclaje": row["id_anclaje"]}


# ============================================================================
# 4. RF-CRUD-04: HORARIOS Y AGENDA DE EVENTOS CULTURALES
# ============================================================================


@router.get("/horarios")
def list_horarios(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: str | None = None,
    sort_dir: str = "asc",
    cod_estado: str | None = None,
    cod_municipio: str | None = None,
    cod_parroquia: str | None = None,
    nombre_hito: str | None = None,
    dia_semana: str | None = None,
    q: str | None = None,
):
    clauses: list[str] = []
    params: dict[str, object] = {}
    if cod_estado and cod_estado.strip():
        clauses.append("hh.cod_estado = %(cod_estado)s")
        params["cod_estado"] = cod_estado.strip()
    if cod_municipio and cod_municipio.strip():
        clauses.append("hh.cod_municipio = %(cod_municipio)s")
        params["cod_municipio"] = cod_municipio.strip()
    if cod_parroquia and cod_parroquia.strip():
        clauses.append("hh.cod_parroquia = %(cod_parroquia)s")
        params["cod_parroquia"] = cod_parroquia.strip()
    if nombre_hito and nombre_hito.strip():
        clauses.append("hh.nombre_hito = %(nombre_hito)s")
        params["nombre_hito"] = nombre_hito.strip()
    if dia_semana and dia_semana.strip():
        clauses.append("hh.dia_semana = %(dia_semana)s")
        params["dia_semana"] = dia_semana.strip()
    if q and q.strip():
        clauses.append(
            "(hh.nombre_hito ILIKE %(q)s OR hh.dia_semana ILIKE %(q)s "
            "OR e.nombre_estado ILIKE %(q)s OR p.nombre_parroquia ILIKE %(q)s)"
        )
        params["q"] = f"%{q.strip()}%"

    base = (
        "Horario_Hito hh "
        "JOIN Hito_Turistico h ON h.cod_estado = hh.cod_estado AND h.cod_municipio = hh.cod_municipio "
        "AND h.cod_parroquia = hh.cod_parroquia AND h.nombre_hito = hh.nombre_hito "
        "JOIN Parroquia p ON p.cod_estado = h.cod_estado AND p.cod_municipio = h.cod_municipio AND p.cod_parroquia = h.cod_parroquia "
        "JOIN Municipio m ON m.cod_estado = p.cod_estado AND m.cod_municipio = p.cod_municipio "
        "JOIN Estado e ON e.cod_estado = m.cod_estado" + _build_where(clauses)
    )
    allowed_sort = {
        "nombre_hito": "hh.nombre_hito",
        "nombre_estado": "e.nombre_estado",
        "dia_semana": "hh.dia_semana",
        "hora_apertura": "hh.hora_apertura",
        "hora_cierre": "hh.hora_cierre",
    }
    with get_db_cursor() as cur:
        return paginate_query(
            cur=cur,
            base_from_where=base,
            select_cols=(
                "hh.cod_estado, e.nombre_estado, hh.cod_municipio, m.nombre_municipio, "
                "hh.cod_parroquia, p.nombre_parroquia, hh.nombre_hito, h.libre_acceso, "
                "hh.dia_semana, hh.hora_apertura, hh.hora_cierre"
            ),
            params=params,
            sort_by=sort_by,
            sort_dir=sort_dir,
            allowed_sort=allowed_sort,
            default_sort="nombre_hito",
            page=page,
            page_size=page_size,
        )


@router.post("/horarios", status_code=201)
def create_horario(payload: HorarioCreate):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            INSERT INTO Horario_Hito (
                cod_estado, cod_municipio, cod_parroquia, nombre_hito,
                dia_semana, hora_apertura, hora_cierre
            ) VALUES (
                %(cod_estado)s, %(cod_municipio)s, %(cod_parroquia)s, %(nombre_hito)s,
                %(dia_semana)s, %(hora_apertura)s, %(hora_cierre)s
            )
            RETURNING cod_estado, cod_municipio, cod_parroquia, nombre_hito,
                      dia_semana, hora_apertura, hora_cierre;
            """,
            payload.model_dump(),
        )
        return serialize_row(cur.fetchone())


@router.put("/horarios")
def update_horario(payload: HorarioUpdate):
    nueva_apertura = payload.hora_apertura_nueva or payload.hora_apertura_actual
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            UPDATE Horario_Hito
            SET hora_apertura = %(hora_apertura_nueva)s,
                hora_cierre = %(hora_cierre)s
            WHERE cod_estado = %(cod_estado)s
              AND cod_municipio = %(cod_municipio)s
              AND cod_parroquia = %(cod_parroquia)s
              AND nombre_hito = %(nombre_hito)s
              AND dia_semana = %(dia_semana)s
              AND hora_apertura = %(hora_apertura_actual)s
            RETURNING cod_estado, cod_municipio, cod_parroquia, nombre_hito,
                      dia_semana, hora_apertura, hora_cierre;
            """,
            {
                "cod_estado": payload.cod_estado,
                "cod_municipio": payload.cod_municipio,
                "cod_parroquia": payload.cod_parroquia,
                "nombre_hito": payload.nombre_hito,
                "dia_semana": payload.dia_semana,
                "hora_apertura_actual": payload.hora_apertura_actual,
                "hora_apertura_nueva": nueva_apertura,
                "hora_cierre": payload.hora_cierre,
            },
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Franja horaria no encontrada.")
        return serialize_row(row)


@router.delete("/horarios")
def delete_horario(
    cod_estado: str = Query(...),
    cod_municipio: str = Query(...),
    cod_parroquia: str = Query(...),
    nombre_hito: str = Query(...),
    dia_semana: str = Query(...),
    hora_apertura: time = Query(...),
):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            DELETE FROM Horario_Hito
            WHERE cod_estado = %(cod_estado)s
              AND cod_municipio = %(cod_municipio)s
              AND cod_parroquia = %(cod_parroquia)s
              AND nombre_hito = %(nombre_hito)s
              AND dia_semana = %(dia_semana)s
              AND hora_apertura = %(hora_apertura)s
            RETURNING dia_semana, hora_apertura;
            """,
            {
                "cod_estado": cod_estado,
                "cod_municipio": cod_municipio,
                "cod_parroquia": cod_parroquia,
                "nombre_hito": nombre_hito,
                "dia_semana": dia_semana,
                "hora_apertura": hora_apertura,
            },
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Franja horaria no encontrada.")
        return {"deleted": True, "dia_semana": row["dia_semana"], "hora_apertura": str(row["hora_apertura"])}


@router.get("/eventos")
def list_eventos(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: str | None = None,
    sort_dir: str = "asc",
    tipo_evento: str | None = None,
    cod_estado: str | None = None,
    q: str | None = None,
):
    clauses: list[str] = []
    params: dict[str, object] = {}
    if tipo_evento and tipo_evento.strip():
        clauses.append("ev.tipo_evento = %(tipo_evento)s")
        params["tipo_evento"] = tipo_evento.strip()
    if cod_estado and cod_estado.strip():
        clauses.append("ev.cod_estado = %(cod_estado)s")
        params["cod_estado"] = cod_estado.strip()
    if q and q.strip():
        clauses.append(
            "(ev.titulo ILIKE %(q)s OR ev.descripcion ILIKE %(q)s "
            "OR ev.tipo_evento ILIKE %(q)s OR COALESCE(ev.nombre_hito, '') ILIKE %(q)s)"
        )
        params["q"] = f"%{q.strip()}%"

    allowed_sort = {
        "id_evento": "ev.id_evento",
        "titulo": "ev.titulo",
        "tipo_evento": "ev.tipo_evento",
        "fecha_inicio": "ev.fecha_inicio",
        "fecha_fin": "ev.fecha_fin",
        "nombre_hito": "ev.nombre_hito",
        "nombre_estado": "ev.nombre_estado",
    }
    with get_db_cursor() as cur:
        return paginate_query(
            cur=cur,
            base_from_where="VW_M1_AGENDA_EVENTOS ev" + _build_where(clauses),
            select_cols="ev.*",
            params=params,
            sort_by=sort_by,
            sort_dir=sort_dir,
            allowed_sort=allowed_sort,
            default_sort="fecha_inicio",
            page=page,
            page_size=page_size,
        )


@router.post("/eventos", status_code=201)
def create_evento(payload: EventoCreate):
    with get_db_cursor(commit=True) as cur:
        has_sede = all([payload.cod_estado, payload.cod_municipio, payload.cod_parroquia, payload.nombre_hito])
        if has_sede:
            cur.execute(
                """
                CALL SP_PROGRAMAR_EVENTO_SEDE(
                    %(titulo)s,
                    %(descripcion)s,
                    %(tipo_evento)s,
                    %(fecha_inicio)s::TIMESTAMP,
                    %(fecha_fin)s::TIMESTAMP,
                    %(cod_estado)s,
                    %(cod_municipio)s,
                    %(cod_parroquia)s,
                    %(nombre_hito)s,
                    NULL
                );
                """,
                payload.model_dump(),
            )
            new_id = cur.fetchone()["p_id_evento"]
        else:
            cur.execute(
                """
                INSERT INTO Evento_Actividad (titulo, descripcion, tipo_evento, fecha_inicio, fecha_fin)
                VALUES (%(titulo)s, %(descripcion)s, %(tipo_evento)s, %(fecha_inicio)s, %(fecha_fin)s)
                RETURNING id_evento;
                """,
                payload.model_dump(),
            )
            new_id = cur.fetchone()["id_evento"]

        cur.execute("SELECT * FROM VW_M1_AGENDA_EVENTOS WHERE id_evento = %s;", (new_id,))
        rows = serialize_rows(cur.fetchall())
        return rows[0] if rows else {"id_evento": new_id}


@router.put("/eventos/{id_evento}")
def update_evento(id_evento: int, payload: EventoUpdate):
    with get_db_cursor(commit=True) as cur:
        params = payload.model_dump()
        params["id_evento"] = id_evento
        cur.execute(
            """
            UPDATE Evento_Actividad
            SET titulo = %(titulo)s,
                descripcion = %(descripcion)s,
                tipo_evento = %(tipo_evento)s,
                fecha_inicio = %(fecha_inicio)s,
                fecha_fin = %(fecha_fin)s
            WHERE id_evento = %(id_evento)s
            RETURNING id_evento, titulo, descripcion, tipo_evento, fecha_inicio, fecha_fin;
            """,
            params,
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail=f"Evento {id_evento} no encontrado.")
        return serialize_row(row)


@router.delete("/eventos/{id_evento}")
def delete_evento(id_evento: int):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            "DELETE FROM Evento_Actividad WHERE id_evento = %(id)s RETURNING id_evento;",
            {"id": id_evento},
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail=f"Evento {id_evento} no encontrado.")
        return {"deleted": True, "id_evento": row["id_evento"]}


@router.post("/eventos/{id_evento}/sedes", status_code=201)
def add_sede_evento(id_evento: int, payload: SedeEventoCreate):
    with get_db_cursor(commit=True) as cur:
        params = payload.model_dump()
        params["id_evento"] = id_evento
        cur.execute(
            """
            INSERT INTO Sede_De_Evento (id_evento, cod_estado, cod_municipio, cod_parroquia, nombre_hito)
            VALUES (%(id_evento)s, %(cod_estado)s, %(cod_municipio)s, %(cod_parroquia)s, %(nombre_hito)s)
            RETURNING id_evento, cod_estado, cod_municipio, cod_parroquia, nombre_hito;
            """,
            params,
        )
        return serialize_row(cur.fetchone())


@router.delete("/eventos/{id_evento}/sedes")
def remove_sede_evento(
    id_evento: int,
    cod_estado: str = Query(...),
    cod_municipio: str = Query(...),
    cod_parroquia: str = Query(...),
    nombre_hito: str = Query(...),
):
    with get_db_cursor(commit=True) as cur:
        cur.execute(
            """
            DELETE FROM Sede_De_Evento
            WHERE id_evento = %(id_evento)s
              AND cod_estado = %(cod_estado)s
              AND cod_municipio = %(cod_municipio)s
              AND cod_parroquia = %(cod_parroquia)s
              AND nombre_hito = %(nombre_hito)s
            RETURNING id_evento;
            """,
            {
                "id_evento": id_evento,
                "cod_estado": cod_estado,
                "cod_municipio": cod_municipio,
                "cod_parroquia": cod_parroquia,
                "nombre_hito": nombre_hito,
            },
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Sede de evento no encontrada.")
        return {"deleted": True, "id_evento": id_evento, "nombre_hito": nombre_hito}


# ============================================================================
# 5. RF-VA-01 Y CONSULTA ESPACIAL M1: VISOR PATRIMONIAL DE REALIDAD AUMENTADA
# ============================================================================


@router.get("/visor-ra")
def consultar_visor_ra(
    latitud: float = Query(..., ge=-90, le=90),
    longitud: float = Query(..., ge=-180, le=180),
    elevacion: float = Query(0.0, ge=0),
    radio_extra_m: float = Query(0.0, ge=0),
):
    with get_db_cursor() as cur:
        cur.execute(
            """
            SELECT *
            FROM FN_CONSULTAR_RA_CERCANA(
                %(latitud)s::NUMERIC,
                %(longitud)s::NUMERIC,
                %(elevacion)s::NUMERIC,
                %(radio_extra_m)s::NUMERIC
            )
            ORDER BY distancia_3d_m ASC;
            """,
            {
                "latitud": latitud,
                "longitud": longitud,
                "elevacion": elevacion,
                "radio_extra_m": radio_extra_m,
            },
        )
        rows = serialize_rows(cur.fetchall())
    return {
        "origen": {
            "latitud": latitud,
            "longitud": longitud,
            "elevacion": elevacion,
            "radio_extra_m": radio_extra_m,
        },
        "total": len(rows),
        "items": rows,
    }


# ============================================================================
# 6. CONSULTA PATRIMONIAL M1: MONUMENTOS NO DE LIBRE ACCESO EN FINES DE SEMANA
# ============================================================================


@router.get("/consultas/patrimonial-fds")
def consulta_patrimonial_fds(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: str | None = None,
    sort_dir: str = "asc",
    cod_estado: str | None = None,
    dia_semana: str | None = None,
    q: str | None = None,
):
    clauses: list[str] = []
    params: dict[str, object] = {}
    if cod_estado and cod_estado.strip():
        clauses.append("f.cod_estado = %(cod_estado)s")
        params["cod_estado"] = cod_estado.strip()
    if dia_semana and dia_semana.strip():
        clauses.append("f.dia_semana = %(dia_semana)s")
        params["dia_semana"] = dia_semana.strip()
    if q and q.strip():
        clauses.append(
            "(f.nombre_hito ILIKE %(q)s OR f.nombre_estado ILIKE %(q)s "
            "OR f.nombre_municipio ILIKE %(q)s OR f.nombre_parroquia ILIKE %(q)s)"
        )
        params["q"] = f"%{q.strip()}%"

    allowed_sort = {
        "nombre_hito": "f.nombre_hito",
        "nombre_estado": "f.nombre_estado",
        "estado_conservacion": "f.estado_conservacion",
        "dia_semana": "f.dia_semana",
        "hora_apertura": "f.hora_apertura",
        "hora_cierre": "f.hora_cierre",
    }
    with get_db_cursor() as cur:
        return paginate_query(
            cur=cur,
            base_from_where="VW_M1_CONSULTA_PATRIMONIAL_FDS f" + _build_where(clauses),
            select_cols="f.*",
            params=params,
            sort_by=sort_by,
            sort_dir=sort_dir,
            allowed_sort=allowed_sort,
            default_sort="nombre_hito",
            page=page,
            page_size=page_size,
        )


# ============================================================================
# 7. REPORTE ESTRATÉGICO M1: INVENTARIO PATRIMONIAL Y CONSERVACIÓN (+ CSV)
# ============================================================================


def _reporte_filter_parts(
    cod_estado: str | None,
    cod_municipio: str | None,
    cod_parroquia: str | None,
    estado_operativo: str | None,
    estado_conservacion: str | None,
    libre_acceso: bool | None,
    id_categoria: int | None,
    q: str | None,
) -> tuple[str, dict[str, object]]:
    view_name = (
        "VW_M1_INVENTARIO_PATRIMONIAL_CAT v"
        if id_categoria is not None
        else "VW_M1_INVENTARIO_PATRIMONIAL v"
    )
    clauses: list[str] = []
    params: dict[str, object] = {}
    if id_categoria is not None:
        clauses.append("v.id_categoria = %(id_categoria)s")
        params["id_categoria"] = id_categoria
    if cod_estado and cod_estado.strip():
        clauses.append("v.cod_estado = %(cod_estado)s")
        params["cod_estado"] = cod_estado.strip()
    if cod_municipio and cod_municipio.strip():
        clauses.append("v.cod_municipio = %(cod_municipio)s")
        params["cod_municipio"] = cod_municipio.strip()
    if cod_parroquia and cod_parroquia.strip():
        clauses.append("v.cod_parroquia = %(cod_parroquia)s")
        params["cod_parroquia"] = cod_parroquia.strip()
    if estado_operativo and estado_operativo.strip():
        clauses.append("v.estado_operativo = %(estado_operativo)s")
        params["estado_operativo"] = estado_operativo.strip()
    if estado_conservacion and estado_conservacion.strip():
        clauses.append("v.estado_conservacion = %(estado_conservacion)s")
        params["estado_conservacion"] = estado_conservacion.strip()
    if libre_acceso is not None:
        clauses.append("v.libre_acceso = %(libre_acceso)s")
        params["libre_acceso"] = libre_acceso
    if q and q.strip():
        clauses.append(
            "(v.nombre_hito ILIKE %(q)s OR v.delimitacion_territorial ILIKE %(q)s "
            "OR v.categorias_lista ILIKE %(q)s)"
        )
        params["q"] = f"%{q.strip()}%"

    return view_name + _build_where(clauses), params


@router.get("/reportes/inventario-patrimonial")
def get_reporte_inventario_patrimonial(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: str | None = None,
    sort_dir: str = "asc",
    cod_estado: str | None = None,
    cod_municipio: str | None = None,
    cod_parroquia: str | None = None,
    estado_operativo: str | None = None,
    estado_conservacion: str | None = None,
    libre_acceso: bool | None = None,
    id_categoria: int | None = None,
    q: str | None = None,
):
    from_where, params = _reporte_filter_parts(
        cod_estado,
        cod_municipio,
        cod_parroquia,
        estado_operativo,
        estado_conservacion,
        libre_acceso,
        id_categoria,
        q,
    )
    allowed_sort = {
        "nombre_hito": "v.nombre_hito",
        "nombre_estado": "v.nombre_estado",
        "nombre_municipio": "v.nombre_municipio",
        "estado_operativo": "v.estado_operativo",
        "estado_conservacion": "v.estado_conservacion",
        "libre_acceso_texto": "v.libre_acceso_texto",
        "elevacion": "v.elevacion",
    }
    estado_kpi = cod_estado.strip() if (cod_estado and cod_estado.strip()) else None

    with get_db_cursor() as cur:
        cur.execute(
            "SELECT * FROM FN_RESUMEN_CONSERVACION_ESTADO(%(cod_estado)s);",
            {"cod_estado": estado_kpi},
        )
        kpis = serialize_row(cur.fetchone())

        paginated = paginate_query(
            cur=cur,
            base_from_where=from_where,
            select_cols="v.*",
            params=params,
            sort_by=sort_by,
            sort_dir=sort_dir,
            allowed_sort=allowed_sort,
            default_sort="nombre_estado",
            page=page,
            page_size=page_size,
        )

    return {"kpis": kpis, **paginated}


@router.get("/reportes/inventario-patrimonial/csv")
def export_reporte_inventario_csv(
    cod_estado: str | None = None,
    cod_municipio: str | None = None,
    cod_parroquia: str | None = None,
    estado_operativo: str | None = None,
    estado_conservacion: str | None = None,
    libre_acceso: bool | None = None,
    id_categoria: int | None = None,
    q: str | None = None,
):
    from_where, params = _reporte_filter_parts(
        cod_estado,
        cod_municipio,
        cod_parroquia,
        estado_operativo,
        estado_conservacion,
        libre_acceso,
        id_categoria,
        q,
    )
    with get_db_cursor() as cur:
        cur.execute(
            f"""
            SELECT
                v.cod_estado,
                v.nombre_estado,
                v.nombre_municipio,
                v.nombre_parroquia,
                v.nombre_hito,
                v.categorias_lista,
                v.estado_operativo,
                v.estado_conservacion,
                v.libre_acceso_texto,
                v.latitud,
                v.longitud,
                v.elevacion
            FROM {from_where}
            ORDER BY v.nombre_estado ASC, v.nombre_hito ASC;
            """,
            params,
        )
        rows = cur.fetchall()

    buffer = io.StringIO()
    buffer.write("\ufeff")  # BOM UTF-8 para compatibilidad directa con Excel
    writer = csv.writer(buffer)
    writer.writerow(
        [
            "Cod_Estado",
            "Estado",
            "Municipio",
            "Parroquia",
            "Hito_Turistico",
            "Categorias",
            "Estado_Operativo",
            "Estado_Conservacion",
            "Libre_Acceso",
            "Latitud",
            "Longitud",
            "Elevacion_msnm",
        ]
    )
    for r in rows:
        writer.writerow(
            [
                r["cod_estado"],
                r["nombre_estado"],
                r["nombre_municipio"],
                r["nombre_parroquia"],
                r["nombre_hito"],
                r["categorias_lista"],
                r["estado_operativo"],
                r["estado_conservacion"],
                r["libre_acceso_texto"],
                r["latitud"],
                r["longitud"],
                r["elevacion"],
            ]
        )

    buffer.seek(0)
    return StreamingResponse(
        iter([buffer.getvalue()]),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": 'attachment; filename="inventario_patrimonial_m1.csv"'},
    )
