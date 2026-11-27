# Módulo 3 · Autor responsable: Leonardo Enrique Chacón Agraz - C.I. 31.895.402
import csv
import io
import secrets
from datetime import date
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from psycopg2 import sql

from ..m3_deps import Database, Pagination, Profile, write_roles
from . import _m3_modelos as models
from .auth import hash_password

router = APIRouter(prefix="/api/m3", tags=["Módulo 3"])
ADMIN = Depends(write_roles("Admin"))
VISITANTE = Depends(write_roles("Visitante"))
CIVIL = Depends(write_roles("Visitante", "Guia", "Admin"))
REPORTANTE = Depends(write_roles("Visitante", "Guia", "Ente", "Admin"))
AUTORIDAD = Depends(write_roles("Ente", "Admin"))
COMERCIO = Depends(write_roles("Comercio", "Admin"))
VALIDADOR = Depends(write_roles("Guia", "Comercio"))
BOLETOS = Depends(write_roles("Visitante", "Guia", "Comercio", "Admin"))
TITULAR_BOLETO = Depends(write_roles("Visitante", "Admin"))
Busqueda = Annotated[str | None, Query(max_length=150)]


def page_of(cur, source, page_options, columns, keys, filters=()):
    page, size, requested, direction = page_options
    sort = requested or keys[0]
    if sort not in columns:
        raise HTTPException(422, "La columna solicitada no admite ordenamiento.")
    criteria = [sql.SQL(condition) for condition, _ in filters]
    arguments = tuple(item for _, values in filters for item in values)
    where = sql.SQL(" WHERE ") + sql.SQL(" AND ").join(criteria) if criteria else sql.SQL("")
    target = sql.Identifier(source)
    cur.execute(sql.SQL("SELECT COUNT(*) AS total FROM {}").format(target) + where, arguments)
    count = cur.fetchone()["total"]
    order = [sql.Identifier(sort) + sql.SQL(" DESC" if direction == "desc" else " ASC")]
    order.extend(sql.Identifier(key) for key in keys if key != sort)
    query = sql.SQL("SELECT * FROM {}").format(target) + where
    query += sql.SQL(" ORDER BY {} LIMIT %s OFFSET %s").format(sql.SQL(", ").join(order))
    cur.execute(query, (*arguments, size, (page - 1) * size))
    return {"items": cur.fetchall(), "total": count, "page": page, "page_size": size,
            "total_pages": max(1, (count + size - 1) // size), "sort_by": sort, "sort_dir": direction}


def filters_for(specs):
    return [(condition, (value,)) for condition, value in specs if value is not None]


def contains(text):
    return f"%{text}%" if text else None


def record(cur):
    row = cur.fetchone()
    if row is None:
        raise HTTPException(404, "Registro no disponible para tu perfil.")
    return row


def insert(cur, table, values, returns=None):
    fields = sql.SQL(", ").join(map(sql.Identifier, values))
    query = sql.SQL("INSERT INTO {} ({}) VALUES ({})").format(
        sql.Identifier(table), fields, sql.SQL(", ").join([sql.Placeholder()] * len(values))
    )
    if returns:
        query += sql.SQL(" RETURNING {}").format(sql.Identifier(returns))
    cur.execute(query, tuple(values.values()))
    return cur.fetchone()[returns] if returns else None


def where_keys(keys):
    return sql.SQL(" AND ").join(sql.SQL("{} = %s").format(sql.Identifier(key)) for key in keys)


def update(cur, table, values, keys):
    assignments = sql.SQL(", ").join(sql.SQL("{} = %s").format(sql.Identifier(key)) for key in values)
    query = sql.SQL("UPDATE {} SET {} WHERE {}").format(sql.Identifier(table), assignments, where_keys(keys))
    cur.execute(query, (*values.values(), *keys.values()))
    if cur.rowcount == 0:
        raise HTTPException(404, "Registro no disponible para edición.")


def delete(cur, table, keys, required=True):
    query = sql.SQL("DELETE FROM {} WHERE {}").format(sql.Identifier(table), where_keys(keys))
    cur.execute(query, tuple(keys.values()))
    if required and cur.rowcount == 0:
        raise HTTPException(404, "Registro no disponible para borrado.")


ACTORES = {
    "Visitante": ("visitante", {"id_reportante": "reportante"},
                  {"accesibilidades": ("accesibilidad_visitante", ("accesibilidad",))}),
    "Guia": ("guia_turistico", {"id_reportante": "reportante", "id_validador": "validador_acceso"},
             {"especialidades": ("especialidad_guia", ("especialidad",)), "idiomas": ("idioma_guia", ("idioma",)),
              "rutas": ("adscrito_a", ("cod_estado", "cod_municipio", "nombre_ruta"))}),
    "Comercio": ("comercio_aliado", {"id_elem_servicio": "elemento_servicio", "id_validador": "validador_acceso"},
                 {"horarios": ("horario_atencion_comercio", ("dia", "apertura", "cierre"))}),
    "Ente": ("ente_publico", {"id_reportante": "reportante"},
             {"tutelas": ("tutela", ("cod_estado", "cod_municipio", "cod_parroquia", "nombre_hito"))}),
}
HITO_FIELDS = ("cod_estado", "cod_municipio", "cod_parroquia", "nombre_hito")


def actor_detail(cur, user_id, lock=False):
    cur.execute(
        "SELECT tipo_actor FROM Actor_Usuario WHERE id_usuario = %s" + (" FOR UPDATE" if lock else ""), (user_id,)
    )
    kind = record(cur)["tipo_actor"]
    table, _, children = ACTORES[kind]
    cur.execute(sql.SQL("SELECT * FROM {} WHERE id_usuario = %s").format(sql.Identifier(table)), (user_id,))
    data = dict(record(cur), tipo_actor=kind)
    if kind == "Comercio":
        values = {field: data.pop(field) for field in HITO_FIELDS}
        data["hito"] = values if values["nombre_hito"] else None
    for field, (child, columns) in children.items():
        names = sql.SQL(", ").join(map(sql.Identifier, columns))
        cur.execute(sql.SQL("SELECT {} FROM {} WHERE id_usuario = %s ORDER BY {}").format(
            names, sql.Identifier(child), names
        ), (user_id,))
        data[field] = [row[columns[0]] if len(columns) == 1 else row for row in cur.fetchall()]
    return data


def write_actor(cur, body, user_id=None):
    kind = body.tipo_actor
    table, categories, children = ACTORES[kind]
    values = body.model_dump(exclude={"tipo_actor", "contrasena", "hito", *children})
    if kind == "Comercio":
        values.update(body.hito.model_dump() if body.hito else dict.fromkeys(HITO_FIELDS))
    hashed = hash_password(body.contrasena.get_secret_value()) if body.contrasena else None
    if user_id is None:
        if hashed is None:
            raise HTTPException(422, "La contraseña es obligatoria al registrar un actor.")
        user_id = insert(cur, "actor_usuario", {"tipo_actor": kind, "contrasena_hash": hashed}, "id_usuario")
        for key, category in categories.items():
            cur.execute(sql.SQL("INSERT INTO {} DEFAULT VALUES RETURNING {}").format(
                sql.Identifier(category), sql.Identifier(key)
            ))
            values[key] = cur.fetchone()[key]
        insert(cur, table, {"id_usuario": user_id, **values})
    else:
        if actor_detail(cur, user_id, lock=True)["tipo_actor"] != kind:
            raise HTTPException(422, "El tipo de actor no se puede cambiar.")
        update(cur, table, values, {"id_usuario": user_id})
        if hashed:
            update(cur, "actor_usuario", {"contrasena_hash": hashed}, {"id_usuario": user_id})
        for child, _ in children.values():
            delete(cur, child, {"id_usuario": user_id}, required=False)
    for field, (child, columns) in children.items():
        for item in getattr(body, field):
            values = {columns[0]: item} if len(columns) == 1 else item.model_dump()
            insert(cur, child, {"id_usuario": user_id, **values})
    return {"id_usuario": user_id}


@router.get("/actores", dependencies=[ADMIN])
def actores(db: Database, paging: Pagination, q: Busqueda = None,
            tipo_actor: Literal["Visitante", "Guia", "Comercio", "Ente"] | None = None):
    return page_of(db, "vw_m3_actores", paging, {"id_usuario", "nombre", "tipo_actor", "identificador"},
                   ("id_usuario",), filters_for([
                       ("concat_ws(' ', nombre, identificador, complemento) ILIKE %s", contains(q)),
                       ("tipo_actor = %s", tipo_actor),
                   ]))


@router.post("/actores", status_code=201, dependencies=[ADMIN])
def crear_actor(body: models.PerfilActor, db: Database):
    return write_actor(db, body)


@router.get("/actores/{user_id}", dependencies=[ADMIN])
def ver_actor(user_id: int, db: Database):
    return actor_detail(db, user_id)


@router.put("/actores/{user_id}", dependencies=[ADMIN])
def editar_actor(user_id: int, body: models.PerfilActor, db: Database, profile: Profile):
    if user_id == profile["id_usuario"] and (
        body.tipo_actor != "Ente" or body.rif_institucional != actor_detail(db, user_id, lock=True)["rif_institucional"]
    ):
        raise HTTPException(409, "El RIF de la cuenta administrativa activa se cambia en la configuración.")
    return write_actor(db, body, user_id)


@router.delete("/actores/{user_id}", status_code=204, dependencies=[ADMIN])
def borrar_actor(user_id: int, db: Database, profile: Profile):
    if user_id == profile["id_usuario"]:
        raise HTTPException(409, "La cuenta de la sesión actual no se puede eliminar.")
    detail = actor_detail(db, user_id, lock=True)
    delete(db, "actor_usuario", {"id_usuario": user_id})
    for key, category in ACTORES[detail["tipo_actor"]][1].items():
        delete(db, category, {key: detail[key]})
    return Response(status_code=204)


@router.get("/catalogos")
def catalogos(db: Database):
    outputs = {}
    for key, view, order in (
        ("rutas", "vw_m3_rutas", "nombre_ruta"), ("servicios", "vw_m3_servicios", "servicio"),
        ("validadores", "vw_m3_validadores", "validador"), ("evaluables", "vw_m3_evaluables", "objeto"),
        ("afectables", "vw_m3_afectables", "elemento"),
    ):
        db.execute(sql.SQL("SELECT * FROM {} ORDER BY {}").format(sql.Identifier(view), sql.Identifier(order)))
        outputs[key] = db.fetchall()
    outputs["guias"] = [row for row in outputs["validadores"] if row["tipo"] == "Guia"]
    outputs["comercios"] = [row for row in outputs["validadores"] if row["tipo"] == "Comercio"]
    outputs["rutas_disponibles"] = bool(outputs["rutas"])
    return outputs


EXPERIENCIA_COLUMNS = {"titulo", "fecha_activacion", "fecha_vencimiento", "precio_total", "cupo_maximo",
                       "porcentaje_descuento", "comercio", "nombre_ruta"}
EXPERIENCIA_KEYS = ("titulo", "fecha_activacion")


@router.get("/experiencias")
def experiencias(db: Database, paging: Pagination, q: Busqueda = None, vigente: bool | None = None,
                 cod_estado: Busqueda = None, cod_municipio: Busqueda = None, nombre_ruta: Busqueda = None,
                 precio_max: Annotated[models.Dinero | None, Query()] = None):
    return page_of(db, "vw_m3_experiencias", paging, EXPERIENCIA_COLUMNS, EXPERIENCIA_KEYS, filters_for([
        ("concat_ws(' ', titulo, descripcion, comercio, codigo_promocional, nombre_ruta) ILIKE %s", contains(q)),
        ("vigente = %s", vigente), ("cod_estado = %s", cod_estado), ("cod_municipio = %s", cod_municipio),
        ("nombre_ruta = %s", nombre_ruta), ("precio_total <= %s", precio_max),
    ]))


def experience_key(titulo, fecha):
    return {"titulo": titulo, "fecha_activacion": fecha}


def experience_values(body, profile, creating=False):
    values = body.model_dump(exclude={"detalles", *EXPERIENCIA_KEYS})
    if profile["perfil"] == "Comercio":
        values["id_usuario_comercio"] = profile["id_usuario"]
        if not creating:
            values.pop("id_usuario_comercio")
    elif body.id_usuario_comercio is None:
        raise HTTPException(422, "Selecciona el comercio promotor.")
    return values


def experience_items(db, keys, details):
    for position, detail in enumerate(details, 1):
        insert(db, "detalle_experiencia", {**keys, "nro_item": position, **detail.model_dump()})


@router.post("/experiencias", status_code=201, dependencies=[COMERCIO])
def crear_experiencia(body: models.Experiencia, db: Database, profile: Profile):
    keys = experience_key(body.titulo, body.fecha_activacion)
    insert(db, "experiencia_promocional", {**keys, **experience_values(body, profile, creating=True)})
    experience_items(db, keys, body.detalles)
    return keys


@router.get("/experiencias/{fecha}/{titulo:path}")
def ver_experiencia(fecha: date, titulo: str, db: Database):
    db.execute("SELECT * FROM VW_M3_EXPERIENCIAS WHERE titulo = %s AND fecha_activacion = %s", (titulo, fecha))
    row = dict(record(db))
    db.execute("""SELECT d.*, s.servicio, s.tipo FROM Detalle_Experiencia d JOIN VW_M3_SERVICIOS s USING (id_elem_servicio)
                  WHERE titulo = %s AND fecha_activacion = %s ORDER BY nro_item""", (titulo, fecha))
    row["detalles"] = db.fetchall()
    return row


@router.put("/experiencias/{fecha}/{titulo:path}", dependencies=[COMERCIO])
def editar_experiencia(fecha: date, titulo: str, body: models.Experiencia, db: Database, profile: Profile):
    if (titulo, fecha) != (body.titulo, body.fecha_activacion):
        raise HTTPException(422, "El título y la fecha de activación identifican la experiencia.")
    keys = experience_key(titulo, fecha)
    update(db, "experiencia_promocional", experience_values(body, profile), keys)
    delete(db, "detalle_experiencia", keys, required=False)
    experience_items(db, keys, body.detalles)
    return keys


@router.delete("/experiencias/{fecha}/{titulo:path}", status_code=204, dependencies=[COMERCIO])
def borrar_experiencia(fecha: date, titulo: str, db: Database):
    delete(db, "experiencia_promocional", experience_key(titulo, fecha))
    return Response(status_code=204)


CREDENCIAL_COLUMNS = {"cod_verificacion", "fecha_hora_visita", "monto_abonado", "cant_beneficiarios",
                      "servicio", "validador", "estado_efectivo"}
EstadoPase = Literal["Emitido", "Canjeado", "Cancelado", "Vencido"]


@router.get("/credenciales", dependencies=[BOLETOS])
def credenciales(db: Database, paging: Pagination, q: Busqueda = None,
                 estado: EstadoPase | None = None, desde: date | None = None, hasta: date | None = None,
                 tipo_servicio: Literal["Hito", "Comercio"] | None = None):
    return page_of(db, "vw_m3_credenciales", paging, CREDENCIAL_COLUMNS, ("cod_verificacion",), filters_for([
        ("concat_ws(' ', cod_verificacion, servicio, validador) ILIKE %s", contains(q)),
        ("estado_efectivo = %s", estado), ("fecha_hora_visita >= %s", desde),
        ("fecha_hora_visita < (%s::date + 1)", hasta), ("tipo_servicio = %s", tipo_servicio),
    ]))


@router.get("/credenciales/emitidas", dependencies=[TITULAR_BOLETO])
def credenciales_emitidas(db: Database, paging: Pagination, profile: Profile, id_usuario: int | None = None):
    user_id = id_usuario if profile["perfil"] == "Admin" else profile["id_usuario"]
    if user_id is None:
        raise HTTPException(422, "Selecciona el ID del visitante.")
    return page_of(db, "vw_m3_credenciales", paging, CREDENCIAL_COLUMNS, ("cod_verificacion",), [
        ("id_usuario = %s", (user_id,)), ("estado_efectivo = 'Emitido' AND tipo_servicio = 'Hito'", ()),
    ])


@router.get("/credenciales/{codigo}", dependencies=[BOLETOS])
def verificar_credencial(codigo: str, db: Database, profile: Profile):
    db.execute("""SELECT c.*, TRUE AS autentica,
        (usuario_validador = %s AND estado_efectivo = 'Emitido'
            AND fecha_hora_visita::DATE = FN_M3_HORA_LOCAL()::DATE
            AND FN_M3_HORARIO_SERVICIO(id_elem_servicio, FN_M3_HORA_LOCAL())) AS canjeable
        FROM VW_M3_CREDENCIALES c WHERE cod_verificacion = %s""", (profile["id_usuario"], codigo))
    return record(db)


@router.post("/credenciales", status_code=201, dependencies=[VISITANTE])
def emitir_credencial(body: models.Credencial, db: Database):
    code = secrets.token_hex(16).upper()
    db.execute("SELECT FN_M3_EMITIR_CREDENCIAL(%s,%s,%s,%s,%s,%s) AS cod_verificacion", (
        code, body.fecha_hora_visita, body.monto_abonado, body.cant_beneficiarios, body.id_elem_servicio, body.id_validador,
    ))
    return record(db)


@router.put("/credenciales/{codigo}", dependencies=[VISITANTE])
def editar_credencial(codigo: str, body: models.Credencial, db: Database):
    db.execute("SELECT %s > FN_M3_HORA_LOCAL() AS futura", (body.fecha_hora_visita,))
    if not db.fetchone()["futura"]:
        raise HTTPException(422, "Selecciona una fecha de visita futura.")
    db.execute("SELECT 1 FROM VW_M3_CREDENCIALES WHERE cod_verificacion = %s AND estado_efectivo = 'Emitido'", (codigo,))
    record(db)
    update(db, "credencial_acceso", body.model_dump(), {"cod_verificacion": codigo})
    return {"cod_verificacion": codigo}


@router.delete("/credenciales/{codigo}", status_code=204, dependencies=[VISITANTE])
def borrar_credencial(codigo: str, db: Database):
    delete(db, "credencial_acceso", {"cod_verificacion": codigo})
    return Response(status_code=204)


@router.post("/credenciales/{codigo}/canjear", status_code=204, dependencies=[VALIDADOR])
def canjear_credencial(codigo: str, db: Database):
    db.execute("CALL SP_CANJEAR_CREDENCIAL(%s)", (codigo,))
    return Response(status_code=204)


@router.post("/credenciales/{codigo}/estado", status_code=204, dependencies=[TITULAR_BOLETO])
def estado_credencial(codigo: str, body: models.CambioCredencial, db: Database):
    db.execute("CALL SP_M3_ESTADO_CREDENCIAL(%s,%s)", (codigo, body.estado_pase))
    return Response(status_code=204)


INCIDENCIA_COLUMNS = {"nro_reporte", "fecha_hora_deteccion", "fecha_estimada_resolucion", "severidad",
                     "elemento", "estado_efectivo", "fecha_limite", "tipo_elemento", "tipo_reportante", "id_reportante"}
EstadoIncidencia = Literal["Preliminar", "Activo", "Fuera de plazo", "Resuelto"]
TipoElemento = Literal["Hito", "Tramo"]


def incident_filters(q, estado, severidad, tipo_elemento, desde, hasta):
    return filters_for([
        ("concat_ws(' ', nro_reporte, elemento, descripcion_evento, ente_confirma) ILIKE %s", contains(q)),
        ("estado_efectivo = %s", estado), ("severidad = %s", severidad),
        ("tipo_elemento = %s", tipo_elemento), ("fecha_hora_deteccion >= %s", desde),
        ("fecha_hora_deteccion < (%s::date + 1)", hasta),
    ])


@router.get("/incidencias")
def incidencias(db: Database, paging: Pagination, q: Busqueda = None, estado: EstadoIncidencia | None = None,
                severidad: models.Severidad | None = None, tipo_elemento: TipoElemento | None = None,
                desde: date | None = None, hasta: date | None = None):
    return page_of(db, "vw_m3_incidencias", paging, INCIDENCIA_COLUMNS, ("nro_reporte",),
                   incident_filters(q, estado, severidad, tipo_elemento, desde, hasta))


@router.get("/incidencias/bandeja", dependencies=[AUTORIDAD])
def bandeja(db: Database, paging: Pagination, solo_visitantes: bool = False):
    filters = [("tipo_reportante = 'Visitante' AND tipo_elemento = 'Hito'", ())] if solo_visitantes else []
    return page_of(db, "vw_m3_bandeja_institucional", paging, INCIDENCIA_COLUMNS, ("nro_reporte",), filters)


@router.get("/incidencias/{number}")
def ver_incidencia(number: int, db: Database, profile: Profile):
    db.execute("SELECT * FROM VW_M3_INCIDENCIAS WHERE nro_reporte = %s", (number,))
    data = dict(record(db))
    if profile["perfil"] in ("Ente", "Admin"):
        db.execute("SELECT * FROM Prorroga_Incidencia WHERE nro_reporte = %s ORDER BY nro_prorroga", (number,))
        data["prorrogas"] = db.fetchall()
    return data


@router.post("/incidencias", status_code=201, dependencies=[REPORTANTE])
def crear_incidencia(body: models.Reporte, db: Database):
    db.execute("SELECT FN_M3_REPORTAR_INCIDENCIA(%s,%s,%s,%s,%s) AS nro_reporte", (
        body.fecha_hora_deteccion, body.fecha_estimada_resolucion, body.descripcion_evento,
        body.severidad, body.id_elem_afectable,
    ))
    return record(db)


@router.put("/incidencias/{number}", dependencies=[CIVIL])
def editar_incidencia(number: int, body: models.ReporteEdicion, db: Database):
    update(db, "reporte_incidencia", body.model_dump(), {"nro_reporte": number, "estado_reporte": "Preliminar"})
    return {"nro_reporte": number}


@router.delete("/incidencias/{number}", status_code=204, dependencies=[CIVIL])
def borrar_incidencia(number: int, db: Database):
    delete(db, "reporte_incidencia", {"nro_reporte": number, "estado_reporte": "Preliminar"})
    return Response(status_code=204)


@router.post("/incidencias/{number}/confirmar", status_code=204, dependencies=[AUTORIDAD])
def confirmar(number: int, body: models.Confirmacion, db: Database):
    db.execute("CALL SP_CONFIRMAR_INCIDENCIA(%s,%s,%s)", (number, body.severidad, body.nueva_fecha_estimada))
    return Response(status_code=204)


@router.post("/incidencias/{number}/prorrogar", status_code=204, dependencies=[AUTORIDAD])
def prorrogar(number: int, body: models.Prorroga, db: Database):
    db.execute("CALL SP_PRORROGAR_INCIDENCIA(%s,%s,%s)", (number, body.nueva_fecha_estimada, body.justificacion))
    return Response(status_code=204)


@router.post("/incidencias/{number}/cerrar", status_code=204, dependencies=[AUTORIDAD])
def cerrar(number: int, db: Database):
    db.execute("CALL SP_CERRAR_INCIDENCIA(%s)", (number,))
    return Response(status_code=204)


EVALUACION_COLUMNS = {"cod_resena", "fecha_emision", "calificacion", "indice_seguridad", "objeto", "visitante"}


@router.get("/evaluaciones")
def evaluaciones(db: Database, paging: Pagination, q: Busqueda = None,
                 tipo_objeto: Literal["Hito", "Ruta"] | None = None, id_obj_evaluable: int | None = None,
                 cod_estado: Busqueda = None, cod_municipio: Busqueda = None, nombre_ruta: Busqueda = None,
                 calificacion_min: Annotated[int | None, Query(ge=1, le=5)] = None):
    filters = filters_for([
        ("concat_ws(' ', opinion, visitante, objeto) ILIKE %s", contains(q)), ("tipo_objeto = %s", tipo_objeto),
        ("id_obj_evaluable = %s", id_obj_evaluable), ("cod_estado = %s", cod_estado),
        ("cod_municipio = %s", cod_municipio), ("tipo_objeto = 'Ruta' AND objeto = %s", nombre_ruta),
        ("calificacion >= %s", calificacion_min),
    ])
    return page_of(db, "vw_m3_evaluaciones", paging, EVALUACION_COLUMNS, ("cod_resena",), filters)


@router.get("/calidad-ruta")
def calidad_ruta(db: Database, cod_estado: str, cod_municipio: str, nombre_ruta: str):
    db.execute("""SELECT total, calificacion_promedio, seguridad_promedio FROM VW_M3_CALIDAD_RUTA
        WHERE cod_estado = %s AND cod_municipio = %s AND nombre_ruta = %s""", (cod_estado, cod_municipio, nombre_ruta))
    return db.fetchone() or {"total": 0, "calificacion_promedio": None, "seguridad_promedio": None}


@router.get("/evaluaciones/{codigo}")
def ver_evaluacion(codigo: str, db: Database):
    db.execute("SELECT * FROM VW_M3_EVALUACIONES WHERE cod_resena = %s", (codigo,))
    return record(db)


@router.post("/evaluaciones", status_code=201, dependencies=[VISITANTE])
def crear_evaluacion(body: models.Evaluacion, db: Database, profile: Profile):
    code = "RV" + secrets.token_hex(12).upper()
    insert(db, "evaluacion_experiencia", {"cod_resena": code, "id_usuario": profile["id_usuario"], **body.model_dump()})
    return {"cod_resena": code}


@router.put("/evaluaciones/{codigo}", dependencies=[VISITANTE])
def editar_evaluacion(codigo: str, body: models.Opinion, db: Database):
    update(db, "evaluacion_experiencia", body.model_dump(), {"cod_resena": codigo})
    return {"cod_resena": codigo}


@router.delete("/evaluaciones/{codigo}", status_code=204, dependencies=[VISITANTE])
def borrar_evaluacion(codigo: str, db: Database):
    delete(db, "evaluacion_experiencia", {"cod_resena": codigo})
    return Response(status_code=204)


@router.get("/observatorio", dependencies=[AUTORIDAD])
def observatorio(db: Database, paging: Pagination, q: Busqueda = None, estado: EstadoIncidencia | None = None,
                severidad: models.Severidad | None = None, tipo_elemento: TipoElemento | None = None,
                desde: date | None = None, hasta: date | None = None):
    filters = incident_filters(q, estado, severidad, tipo_elemento, desde, hasta)
    result = page_of(db, "vw_m3_observatorio", paging, INCIDENCIA_COLUMNS, ("nro_reporte",), filters)
    where = " WHERE " + " AND ".join(condition for condition, _ in filters) if filters else ""
    args = tuple(value for _, values in filters for value in values)
    db.execute("""SELECT COUNT(*) FILTER (WHERE estado_efectivo = 'Activo') AS activas,
        COALESCE(ROUND(100.0 * COUNT(*) FILTER (WHERE severidad = 'Critico') / NULLIF(COUNT(*),0),2),0) AS porcentaje_criticas,
        COUNT(*) FILTER (WHERE prorroga_activa) AS prorrogas_activas,
        ROUND(AVG(horas_confirmacion),2) AS horas_promedio_confirmacion,
        ROUND(AVG(horas_cierre),2) AS horas_promedio_cierre
        FROM VW_M3_OBSERVATORIO""" + where, args)
    result["indicadores"] = db.fetchone()
    return result


@router.get("/observatorio.csv", dependencies=[AUTORIDAD])
def observatorio_csv(db: Database, q: Busqueda = None, estado: EstadoIncidencia | None = None,
                    severidad: models.Severidad | None = None, tipo_elemento: TipoElemento | None = None,
                    desde: date | None = None, hasta: date | None = None):
    filters = incident_filters(q, estado, severidad, tipo_elemento, desde, hasta)
    where = " WHERE " + " AND ".join(condition for condition, _ in filters) if filters else ""
    fields = ("nro_reporte", "fecha_hora_deteccion", "elemento", "id_reportante", "severidad", "fecha_limite",
              "estado_efectivo", "ente_confirma", "ente_cierra", "horas_confirmacion", "horas_cierre")
    db.execute("SELECT " + ", ".join(fields) + " FROM VW_M3_OBSERVATORIO" + where + " ORDER BY nro_reporte",
               tuple(value for _, values in filters for value in values))
    stream = io.StringIO()
    writer = csv.writer(stream)
    writer.writerow(fields)
    for row in db:
        writer.writerow("'" + value if isinstance(value, str) and value.lstrip().startswith(("=", "+", "-", "@")) else value
                        for value in row.values())
    return Response("\ufeff" + stream.getvalue(), media_type="text/csv",
                    headers={"Content-Disposition": "attachment; filename=observatorio-incidencias.csv"})
