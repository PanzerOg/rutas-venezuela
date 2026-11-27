# Módulo 3 · Autor responsable: Leonardo Enrique Chacón Agraz - C.I. 31.895.402
from datetime import date, datetime, time
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, NaiveDatetime, SecretStr, StringConstraints

Nombre = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=150)]
Texto = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=3000)]
Codigo = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=40)]
Id = Annotated[int, Field(gt=0, le=2_147_483_647)]
Dinero = Annotated[Decimal, Field(ge=0, max_digits=12, decimal_places=2, allow_inf_nan=False)]
Severidad = Literal["Bajo", "Medio", "Critico"]


class Formulario(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Hito(Formulario):
    cod_estado: Codigo
    cod_municipio: Codigo
    cod_parroquia: Codigo
    nombre_hito: Nombre


class Ruta(Formulario):
    cod_estado: Codigo
    cod_municipio: Codigo
    nombre_ruta: Nombre


class Horario(Formulario):
    dia: Literal["Lunes", "Martes", "Miercoles", "Jueves", "Viernes", "Sabado", "Domingo"]
    apertura: time
    cierre: time


class Actor(Formulario):
    contrasena: SecretStr | None = Field(default=None, min_length=10, max_length=128)


class Visitante(Actor):
    tipo_actor: Literal["Visitante"]
    doc_identidad: Codigo
    tipo_documento: Literal["Cedula", "Pasaporte"]
    nombres: Nombre
    apellidos: Nombre
    pais_origen: Nombre
    idioma_nativo: Nombre
    tel_emergencia: Codigo
    grupo_sanguineo: Literal["O+", "O-", "A+", "A-", "B+", "B-", "AB+", "AB-"]
    accesibilidades: list[Nombre] = Field(default_factory=list, max_length=30)


class Guia(Actor):
    tipo_actor: Literal["Guia"]
    nro_rtn: Codigo
    cod_licencia: Codigo
    acreditacion_oficial: Texto
    anios_trayectoria: Annotated[int, Field(ge=0, le=32767)]
    tarifa_hora: Dinero
    zona_asignada: Nombre
    especialidades: list[Nombre] = Field(default_factory=list, max_length=30)
    idiomas: list[Nombre] = Field(default_factory=list, max_length=30)
    rutas: list[Ruta] = Field(default_factory=list, max_length=100)


class Comercio(Actor):
    tipo_actor: Literal["Comercio"]
    rif_comercio: Codigo
    razon_social: Nombre
    categoria_comercial: Nombre
    aforo: Id
    nro_permiso_sanitario: Codigo
    cuenta_bancaria: Codigo
    hito: Hito | None = None
    horarios: list[Horario] = Field(default_factory=list, max_length=50)


class Ente(Actor):
    tipo_actor: Literal["Ente"]
    rif_institucional: Codigo
    denominacion_oficial: Nombre
    nivel_territorial: Literal["Nacional", "Estadal", "Municipal", "Parroquial"]
    funcionario_enlace: Nombre
    decreto_adscripcion: Nombre
    tutelas: list[Hito] = Field(default_factory=list, max_length=100)


PerfilActor = Annotated[Visitante | Guia | Comercio | Ente, Field(discriminator="tipo_actor")]


class Detalle(Formulario):
    id_elem_servicio: Id
    costo_individual: Dinero


class Experiencia(Ruta):
    titulo: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=160)]
    fecha_activacion: date
    descripcion: Texto
    precio_total: Dinero
    cupo_maximo: Id
    porcentaje_descuento: Annotated[Decimal, Field(ge=0, le=100, decimal_places=2)]
    fecha_vencimiento: date
    codigo_promocional: Codigo | None = None
    id_usuario_comercio: Id | None = None
    id_usuario_guia: Id
    detalles: list[Detalle] = Field(min_length=1, max_length=100)


class Credencial(Formulario):
    fecha_hora_visita: NaiveDatetime
    monto_abonado: Dinero
    cant_beneficiarios: Id
    id_elem_servicio: Id
    id_validador: Id


class CambioCredencial(Formulario):
    estado_pase: Literal["Cancelado", "Vencido"]


class ReporteEdicion(Formulario):
    fecha_estimada_resolucion: date
    descripcion_evento: Texto
    severidad: Severidad
    id_elem_afectable: Id


class Reporte(ReporteEdicion):
    fecha_hora_deteccion: NaiveDatetime


class Confirmacion(Formulario):
    severidad: Severidad
    nueva_fecha_estimada: date | None = None


class Prorroga(Formulario):
    nueva_fecha_estimada: date
    justificacion: Texto


class Opinion(Formulario):
    calificacion: Annotated[int, Field(ge=1, le=5)]
    indice_seguridad: Annotated[int, Field(ge=1, le=5)]
    opinion: Texto


class Evaluacion(Opinion):
    id_obj_evaluable: Id
