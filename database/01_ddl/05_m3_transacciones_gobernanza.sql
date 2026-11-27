-- Módulo 3 · Autor responsable: Leonardo Enrique Chacón Agraz - C.I. 31.895.402
BEGIN;

CREATE TABLE Adscrito_A (
    cod_estado VARCHAR(6),
    cod_municipio VARCHAR(10),
    nombre_ruta VARCHAR(150),
    id_usuario INTEGER,
    CONSTRAINT PK_ADSCRITO_A PRIMARY KEY (cod_estado, cod_municipio, nombre_ruta, id_usuario),
    CONSTRAINT FK_ADSCRITO_A_GUIA FOREIGN KEY (id_usuario)
        REFERENCES Guia_Turistico ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE Experiencia_Promocional (
    titulo VARCHAR(160),
    fecha_activacion DATE,
    descripcion TEXT NOT NULL,
    precio_total NUMERIC(12,2) NOT NULL,
    cupo_maximo INTEGER NOT NULL,
    porcentaje_descuento NUMERIC(5,2) NOT NULL,
    fecha_vencimiento DATE NOT NULL,
    codigo_promocional VARCHAR(40),
    id_usuario_comercio INTEGER NOT NULL,
    id_usuario_guia INTEGER NOT NULL,
    cod_estado VARCHAR(6) NOT NULL,
    cod_municipio VARCHAR(10) NOT NULL,
    nombre_ruta VARCHAR(150) NOT NULL,
    CONSTRAINT PK_EXPERIENCIA_PROMOCIONAL PRIMARY KEY (titulo, fecha_activacion),
    CONSTRAINT AK_EXPERIENCIA_PROMOCIONAL_COD UNIQUE (codigo_promocional),
    CONSTRAINT FK_EXPERIENCIA_COMERCIO FOREIGN KEY (id_usuario_comercio) REFERENCES Comercio_Aliado ON UPDATE CASCADE,
    CONSTRAINT FK_EXPERIENCIA_GUIA FOREIGN KEY (id_usuario_guia) REFERENCES Guia_Turistico ON UPDATE CASCADE,
    CONSTRAINT DOM_EXPERIENCIA__TITULO CHECK (btrim(titulo) <> ''),
    CONSTRAINT DOM_EXPERIENCIA__CODIGO CHECK (btrim(codigo_promocional) <> ''),
    CONSTRAINT DOM_EXPERIENCIA__PRECIO CHECK (precio_total >= 0 AND precio_total <> 'NaN'),
    CONSTRAINT DOM_EXPERIENCIA__CUPO CHECK (cupo_maximo >= 1),
    CONSTRAINT DOM_EXPERIENCIA__DESCUENTO CHECK (porcentaje_descuento BETWEEN 0 AND 100),
    CONSTRAINT EXP_EXPERIENCIA_R_1 CHECK (fecha_vencimiento > fecha_activacion)
);

-- El ZIP inicial permite instalar M3 sin M2. La carga integrada activa las FK reales.
DO $$
BEGIN
    IF to_regclass('public.ruta') IS NULL THEN
        ALTER TABLE Adscrito_A ADD CONSTRAINT EXP_ADSCRITO_A_REQUIERE_M2 CHECK (FALSE);
        ALTER TABLE Experiencia_Promocional ADD CONSTRAINT EXP_EXPERIENCIA_REQUIERE_M2 CHECK (FALSE);
        RAISE NOTICE 'Módulo 2 pendiente: las experiencias y adscripciones se habilitan con el DDL de Ruta.';
    ELSE
        ALTER TABLE Adscrito_A ADD CONSTRAINT FK_ADSCRITO_A_RUTA
            FOREIGN KEY (cod_estado, cod_municipio, nombre_ruta) REFERENCES Ruta
            ON UPDATE CASCADE ON DELETE CASCADE;
        ALTER TABLE Experiencia_Promocional ADD CONSTRAINT FK_EXPERIENCIA_RUTA
            FOREIGN KEY (cod_estado, cod_municipio, nombre_ruta) REFERENCES Ruta
            ON UPDATE CASCADE;
    END IF;
END;
$$;

CREATE TABLE Detalle_Experiencia (
    titulo VARCHAR(160),
    fecha_activacion DATE,
    nro_item INTEGER,
    costo_individual NUMERIC(12,2) NOT NULL,
    id_elem_servicio INTEGER NOT NULL,
    CONSTRAINT PK_DETALLE_EXPERIENCIA PRIMARY KEY (titulo, fecha_activacion, nro_item),
    CONSTRAINT AK_DETALLE_EXPERIENCIA_SERV UNIQUE (titulo, fecha_activacion, id_elem_servicio),
    CONSTRAINT FK_DETALLE_EXPERIENCIA_EXP FOREIGN KEY (titulo, fecha_activacion)
        REFERENCES Experiencia_Promocional ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT FK_DETALLE_EXPERIENCIA_SERV FOREIGN KEY (id_elem_servicio) REFERENCES Elemento_Servicio ON UPDATE CASCADE,
    CONSTRAINT DOM_DETALLE_EXPERIENCIA__NRO CHECK (nro_item >= 1),
    CONSTRAINT DOM_DETALLE_EXPERIENCIA__COSTO CHECK (costo_individual >= 0 AND costo_individual <> 'NaN')
);

CREATE TABLE Credencial_Acceso (
    cod_verificacion VARCHAR(64),
    fecha_hora_visita TIMESTAMP NOT NULL,
    monto_abonado NUMERIC(12,2) NOT NULL,
    cant_beneficiarios INTEGER NOT NULL,
    estado_pase VARCHAR(10) NOT NULL DEFAULT 'Emitido',
    fecha_hora_canje TIMESTAMP,
    id_usuario INTEGER NOT NULL,
    id_elem_servicio INTEGER NOT NULL,
    id_validador INTEGER NOT NULL,
    CONSTRAINT PK_CREDENCIAL_ACCESO PRIMARY KEY (cod_verificacion),
    CONSTRAINT FK_CREDENCIAL_VISITANTE FOREIGN KEY (id_usuario) REFERENCES Visitante ON UPDATE CASCADE,
    CONSTRAINT FK_CREDENCIAL_SERVICIO FOREIGN KEY (id_elem_servicio) REFERENCES Elemento_Servicio ON UPDATE CASCADE,
    CONSTRAINT FK_CREDENCIAL_VALIDADOR FOREIGN KEY (id_validador) REFERENCES Validador_Acceso ON UPDATE CASCADE,
    CONSTRAINT DOM_CREDENCIAL__CODIGO CHECK (cod_verificacion ~ '^[A-Za-z0-9]+$'),
    CONSTRAINT DOM_CREDENCIAL__MONTO CHECK (monto_abonado >= 0 AND monto_abonado <> 'NaN'),
    CONSTRAINT DOM_CREDENCIAL__BENEF CHECK (cant_beneficiarios >= 1),
    CONSTRAINT DOM_CREDENCIAL__ESTADO CHECK (estado_pase IN ('Emitido','Canjeado','Cancelado','Vencido')),
    CONSTRAINT EXP_CREDENCIAL_R_1 CHECK ((estado_pase = 'Canjeado') = (fecha_hora_canje IS NOT NULL)),
    CONSTRAINT EXP_CREDENCIAL_R_2 CHECK (
        fecha_hora_canje::DATE = fecha_hora_visita::DATE AND fecha_hora_canje <= fecha_hora_visita
    )
);

CREATE TABLE Evaluacion_Experiencia (
    cod_resena VARCHAR(64),
    calificacion SMALLINT NOT NULL,
    indice_seguridad SMALLINT NOT NULL,
    fecha_emision TIMESTAMP NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'America/Caracas'),
    opinion TEXT NOT NULL,
    recorrido_verificado BOOLEAN NOT NULL DEFAULT TRUE,
    id_usuario INTEGER NOT NULL,
    id_obj_evaluable INTEGER NOT NULL,
    CONSTRAINT PK_EVALUACION_EXPERIENCIA PRIMARY KEY (cod_resena),
    CONSTRAINT FK_EVALUACION_VISITANTE FOREIGN KEY (id_usuario) REFERENCES Visitante ON UPDATE CASCADE,
    CONSTRAINT FK_EVALUACION_OBJ_EVAL FOREIGN KEY (id_obj_evaluable) REFERENCES Objeto_Evaluable ON UPDATE CASCADE,
    CONSTRAINT DOM_EVALUACION__CALIFICACION CHECK (calificacion BETWEEN 1 AND 5),
    CONSTRAINT DOM_EVALUACION__SEGURIDAD CHECK (indice_seguridad BETWEEN 1 AND 5),
    CONSTRAINT DOM_EVALUACION__OPINION CHECK (btrim(opinion) <> ''),
    CONSTRAINT EXP_EVALUACION_R_1 CHECK (recorrido_verificado)
);

CREATE TABLE Reporte_Incidencia (
    nro_reporte INTEGER GENERATED BY DEFAULT AS IDENTITY,
    fecha_hora_deteccion TIMESTAMP NOT NULL,
    fecha_estimada_resolucion DATE NOT NULL,
    descripcion_evento TEXT NOT NULL,
    estado_reporte VARCHAR(10) NOT NULL DEFAULT 'Preliminar',
    severidad VARCHAR(10) NOT NULL,
    id_reportante INTEGER NOT NULL,
    id_elem_afectable INTEGER NOT NULL,
    id_usuario_confirma INTEGER,
    fecha_confirmacion TIMESTAMP,
    id_usuario_cierra INTEGER,
    fecha_cierre TIMESTAMP,
    CONSTRAINT PK_REPORTE_INCIDENCIA PRIMARY KEY (nro_reporte),
    CONSTRAINT FK_REPORTE_REPORTANTE FOREIGN KEY (id_reportante) REFERENCES Reportante ON UPDATE CASCADE,
    CONSTRAINT FK_REPORTE_ELEM_AFEC FOREIGN KEY (id_elem_afectable) REFERENCES Elemento_Afectable ON UPDATE CASCADE,
    CONSTRAINT FK_REPORTE_ENTE_CONFIRMA FOREIGN KEY (id_usuario_confirma) REFERENCES Ente_Publico ON UPDATE CASCADE,
    CONSTRAINT FK_REPORTE_ENTE_CIERRA FOREIGN KEY (id_usuario_cierra) REFERENCES Ente_Publico ON UPDATE CASCADE,
    CONSTRAINT DOM_REPORTE__ESTADO CHECK (estado_reporte IN ('Preliminar','Activo','Resuelto')),
    CONSTRAINT DOM_REPORTE__SEVERIDAD CHECK (severidad IN ('Bajo','Medio','Critico')),
    CONSTRAINT DOM_REPORTE__DESCRIPCION CHECK (btrim(descripcion_evento) <> ''),
    CONSTRAINT EXP_REPORTE_R_1 CHECK (fecha_estimada_resolucion >= fecha_hora_deteccion::DATE),
    CONSTRAINT EXP_REPORTE_R_2 CHECK (
        (estado_reporte <> 'Preliminar') = (id_usuario_confirma IS NOT NULL)
        AND (id_usuario_confirma IS NULL) = (fecha_confirmacion IS NULL)
        AND (fecha_confirmacion IS NULL OR fecha_confirmacion >= fecha_hora_deteccion)
    ),
    CONSTRAINT EXP_REPORTE_R_3 CHECK (
        (estado_reporte = 'Resuelto') = (id_usuario_cierra IS NOT NULL)
        AND (id_usuario_cierra IS NULL) = (fecha_cierre IS NULL)
        AND (fecha_cierre IS NULL OR fecha_cierre >= fecha_confirmacion)
    )
);

CREATE TABLE Prorroga_Incidencia (
    nro_reporte INTEGER,
    nro_prorroga INTEGER,
    nueva_fecha_estimada DATE NOT NULL,
    justificacion TEXT NOT NULL,
    fecha_registro TIMESTAMP NOT NULL DEFAULT (clock_timestamp() AT TIME ZONE 'America/Caracas'),
    CONSTRAINT PK_PRORROGA_INCIDENCIA PRIMARY KEY (nro_reporte, nro_prorroga),
    CONSTRAINT FK_PRORROGA_REPORTE FOREIGN KEY (nro_reporte)
        REFERENCES Reporte_Incidencia ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT DOM_PRORROGA__NRO CHECK (nro_prorroga >= 1),
    CONSTRAINT DOM_PRORROGA__JUSTIFICACION CHECK (btrim(justificacion) <> '')
);

COMMIT;
