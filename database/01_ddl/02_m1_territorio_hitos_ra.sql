-- ============================================================================
-- Archivo: 02_m1_territorio_hitos_ra.sql
-- Módulo: Módulo 1 - Territorio, Hitos Turísticos y Realidad Aumentada
-- Autor responsable: José Alejandro Montes de Oca Tineo - C.I. 31.066.053
-- Descripción: Creación de las 11 tablas del Módulo 1 con tipos primitivos
--              estándar (sin extensiones espaciales) y nomenclatura de
--              constraints de cátedra (PK_, AK_, FK_, DOM_, EXP_).
-- ============================================================================

-- 1. ESTADO
CREATE TABLE Estado (
    cod_estado    VARCHAR(6)   NOT NULL,
    nombre_estado VARCHAR(100) NOT NULL,
    CONSTRAINT PK_ESTADO PRIMARY KEY (cod_estado),
    CONSTRAINT AK_ESTADO_NOMBRE UNIQUE (nombre_estado),
    CONSTRAINT DOM_ESTADO__COD_ESTADO CHECK (TRIM(cod_estado) <> ''),
    CONSTRAINT DOM_ESTADO__NOMBRE_ESTADO CHECK (TRIM(nombre_estado) <> '')
);

-- 2. MUNICIPIO (entidad débil identificante de ESTADO)
CREATE TABLE Municipio (
    cod_estado       VARCHAR(6)   NOT NULL,
    cod_municipio    VARCHAR(10)  NOT NULL,
    nombre_municipio VARCHAR(120) NOT NULL,
    CONSTRAINT PK_MUNICIPIO PRIMARY KEY (cod_estado, cod_municipio),
    CONSTRAINT AK_MUNICIPIO_NOMBRE UNIQUE (cod_estado, nombre_municipio),
    CONSTRAINT FK_MUNICIPIO_ESTADO FOREIGN KEY (cod_estado)
        REFERENCES Estado (cod_estado)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT DOM_MUNICIPIO__COD_MUNICIPIO CHECK (TRIM(cod_municipio) <> ''),
    CONSTRAINT DOM_MUNICIPIO__NOMBRE_MUNICIPIO CHECK (TRIM(nombre_municipio) <> '')
);

-- 3. PARROQUIA (entidad débil identificante de MUNICIPIO)
CREATE TABLE Parroquia (
    cod_estado       VARCHAR(6)   NOT NULL,
    cod_municipio    VARCHAR(10)  NOT NULL,
    cod_parroquia    VARCHAR(10)  NOT NULL,
    nombre_parroquia VARCHAR(120) NOT NULL,
    tipo_demarcacion VARCHAR(15)  NOT NULL,
    CONSTRAINT PK_PARROQUIA PRIMARY KEY (cod_estado, cod_municipio, cod_parroquia),
    CONSTRAINT AK_PARROQUIA_NOMBRE UNIQUE (cod_estado, cod_municipio, nombre_parroquia),
    CONSTRAINT FK_PARROQUIA_MUNICIPIO FOREIGN KEY (cod_estado, cod_municipio)
        REFERENCES Municipio (cod_estado, cod_municipio)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT DOM_PARROQUIA__COD_PARROQUIA CHECK (TRIM(cod_parroquia) <> ''),
    CONSTRAINT DOM_PARROQUIA__NOMBRE_PARROQUIA CHECK (TRIM(nombre_parroquia) <> ''),
    CONSTRAINT DOM_PARROQUIA__TIPO_DEMARCACION CHECK (tipo_demarcacion IN ('Urbana', 'Rural', 'Mixta'))
);

-- 4. HITO_TURISTICO (entidad débil identificante de PARROQUIA; permite compartir coordenadas 3D)
CREATE TABLE Hito_Turistico (
    cod_estado          VARCHAR(6)    NOT NULL,
    cod_municipio       VARCHAR(10)   NOT NULL,
    cod_parroquia       VARCHAR(10)   NOT NULL,
    nombre_hito         VARCHAR(150)  NOT NULL,
    descripcion         TEXT          NOT NULL,
    estado_operativo    VARCHAR(30)   NOT NULL,
    libre_acceso        BOOLEAN       NOT NULL,
    estado_conservacion VARCHAR(20)   NOT NULL,
    latitud             NUMERIC(9,6)  NOT NULL,
    longitud            NUMERIC(9,6)  NOT NULL,
    elevacion           NUMERIC(8,2)  NOT NULL,
    id_punto_itin       INTEGER       NOT NULL,
    id_elem_afectable   INTEGER       NOT NULL,
    id_obj_evaluable    INTEGER       NOT NULL,
    id_elem_servicio    INTEGER       NOT NULL,
    CONSTRAINT PK_HITO_TURISTICO PRIMARY KEY (cod_estado, cod_municipio, cod_parroquia, nombre_hito),
    CONSTRAINT AK_HITO_TURISTICO_PUNTO_ITIN UNIQUE (id_punto_itin),
    CONSTRAINT AK_HITO_TURISTICO_ELEM_AFEC UNIQUE (id_elem_afectable),
    CONSTRAINT AK_HITO_TURISTICO_OBJ_EVAL UNIQUE (id_obj_evaluable),
    CONSTRAINT AK_HITO_TURISTICO_ELEM_SERV UNIQUE (id_elem_servicio),
    CONSTRAINT FK_HITO_TURISTICO_PARROQUIA FOREIGN KEY (cod_estado, cod_municipio, cod_parroquia)
        REFERENCES Parroquia (cod_estado, cod_municipio, cod_parroquia)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT FK_HITO_TURISTICO_PUNTO_ITINERARIO FOREIGN KEY (id_punto_itin)
        REFERENCES Punto_Itinerario (id_punto_itin)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT FK_HITO_TURISTICO_ELEMENTO_AFECTABLE FOREIGN KEY (id_elem_afectable)
        REFERENCES Elemento_Afectable (id_elem_afectable)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT FK_HITO_TURISTICO_OBJETO_EVALUABLE FOREIGN KEY (id_obj_evaluable)
        REFERENCES Objeto_Evaluable (id_obj_evaluable)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT FK_HITO_TURISTICO_ELEMENTO_SERVICIO FOREIGN KEY (id_elem_servicio)
        REFERENCES Elemento_Servicio (id_elem_servicio)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT DOM_HITO_TURISTICO__NOMBRE_HITO CHECK (TRIM(nombre_hito) <> ''),
    CONSTRAINT DOM_HITO_TURISTICO__ESTADO_OPERATIVO CHECK (
        estado_operativo IN ('Disponible', 'En restauracion', 'Clausurado temporalmente', 'Cerrado permanentemente')
    ),
    CONSTRAINT DOM_HITO_TURISTICO__ESTADO_CONSERVACION CHECK (
        estado_conservacion IN ('Optimo', 'Bueno', 'Regular', 'Deteriorado', 'Critico')
    ),
    CONSTRAINT DOM_HITO_TURISTICO__LATITUD CHECK (latitud BETWEEN -90 AND 90),
    CONSTRAINT DOM_HITO_TURISTICO__LONGITUD CHECK (longitud BETWEEN -180 AND 180),
    CONSTRAINT DOM_HITO_TURISTICO__ELEVACION CHECK (elevacion >= 0)
);

-- 5. CATEGORIA
CREATE TABLE Categoria (
    id_categoria     INTEGER GENERATED BY DEFAULT AS IDENTITY,
    nombre_categoria VARCHAR(100) NOT NULL,
    descripcion      TEXT         NOT NULL,
    CONSTRAINT PK_CATEGORIA PRIMARY KEY (id_categoria),
    CONSTRAINT AK_CATEGORIA_NOMBRE UNIQUE (nombre_categoria),
    CONSTRAINT DOM_CATEGORIA__NOMBRE_CATEGORIA CHECK (TRIM(nombre_categoria) <> '')
);

-- 6. HITO_CATEGORIA (interrelación M:N CLASIFICADO_EN)
CREATE TABLE Hito_Categoria (
    cod_estado    VARCHAR(6)   NOT NULL,
    cod_municipio VARCHAR(10)  NOT NULL,
    cod_parroquia VARCHAR(10)  NOT NULL,
    nombre_hito   VARCHAR(150) NOT NULL,
    id_categoria  INTEGER      NOT NULL,
    CONSTRAINT PK_HITO_CATEGORIA PRIMARY KEY (cod_estado, cod_municipio, cod_parroquia, nombre_hito, id_categoria),
    CONSTRAINT FK_HITO_CATEGORIA_HITO_TURISTICO FOREIGN KEY (cod_estado, cod_municipio, cod_parroquia, nombre_hito)
        REFERENCES Hito_Turistico (cod_estado, cod_municipio, cod_parroquia, nombre_hito)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT FK_HITO_CATEGORIA_CATEGORIA FOREIGN KEY (id_categoria)
        REFERENCES Categoria (id_categoria)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- 7. HORARIO_HITO (entidad débil con clave parcial compuesta: dia_semana, hora_apertura)
CREATE TABLE Horario_Hito (
    cod_estado    VARCHAR(6)   NOT NULL,
    cod_municipio VARCHAR(10)  NOT NULL,
    cod_parroquia VARCHAR(10)  NOT NULL,
    nombre_hito   VARCHAR(150) NOT NULL,
    dia_semana    VARCHAR(15)  NOT NULL,
    hora_apertura TIME         NOT NULL,
    hora_cierre   TIME         NOT NULL,
    CONSTRAINT PK_HORARIO_HITO PRIMARY KEY (cod_estado, cod_municipio, cod_parroquia, nombre_hito, dia_semana, hora_apertura),
    CONSTRAINT FK_HORARIO_HITO_HITO_TURISTICO FOREIGN KEY (cod_estado, cod_municipio, cod_parroquia, nombre_hito)
        REFERENCES Hito_Turistico (cod_estado, cod_municipio, cod_parroquia, nombre_hito)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT DOM_HORARIO_HITO__DIA_SEMANA CHECK (
        dia_semana IN ('Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes', 'Sabado', 'Domingo')
    ),
    CONSTRAINT EXP_HORARIO_HITO_R_1 CHECK (hora_cierre > hora_apertura)
);

-- 8. EVENTO_ACTIVIDAD
CREATE TABLE Evento_Actividad (
    id_evento    INTEGER GENERATED BY DEFAULT AS IDENTITY,
    titulo       VARCHAR(160) NOT NULL,
    descripcion  TEXT         NOT NULL,
    tipo_evento  VARCHAR(60)  NOT NULL,
    fecha_inicio TIMESTAMP    NOT NULL,
    fecha_fin    TIMESTAMP    NOT NULL,
    CONSTRAINT PK_EVENTO_ACTIVIDAD PRIMARY KEY (id_evento),
    CONSTRAINT DOM_EVENTO_ACTIVIDAD__TITULO CHECK (TRIM(titulo) <> ''),
    CONSTRAINT DOM_EVENTO_ACTIVIDAD__TIPO_EVENTO CHECK (TRIM(tipo_evento) <> ''),
    CONSTRAINT EXP_EVENTO_ACTIVIDAD_R_1 CHECK (fecha_fin > fecha_inicio)
);

-- 9. SEDE_DE_EVENTO (interrelación M:N SEDE_DE)
CREATE TABLE Sede_De_Evento (
    id_evento     INTEGER      NOT NULL,
    cod_estado    VARCHAR(6)   NOT NULL,
    cod_municipio VARCHAR(10)  NOT NULL,
    cod_parroquia VARCHAR(10)  NOT NULL,
    nombre_hito   VARCHAR(150) NOT NULL,
    CONSTRAINT PK_SEDE_DE_EVENTO PRIMARY KEY (id_evento, cod_estado, cod_municipio, cod_parroquia, nombre_hito),
    CONSTRAINT FK_SEDE_DE_EVENTO_EVENTO_ACTIVIDAD FOREIGN KEY (id_evento)
        REFERENCES Evento_Actividad (id_evento)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT FK_SEDE_DE_EVENTO_HITO_TURISTICO FOREIGN KEY (cod_estado, cod_municipio, cod_parroquia, nombre_hito)
        REFERENCES Hito_Turistico (cod_estado, cod_municipio, cod_parroquia, nombre_hito)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- 10. RECURSO_3D
CREATE TABLE Recurso_3D (
    cod_recurso_3d VARCHAR(40) NOT NULL,
    tipo_recurso   VARCHAR(60) NOT NULL,
    descripcion    TEXT        NOT NULL,
    CONSTRAINT PK_RECURSO_3D PRIMARY KEY (cod_recurso_3d),
    CONSTRAINT DOM_RECURSO_3D__COD_RECURSO_3D CHECK (TRIM(cod_recurso_3d) <> ''),
    CONSTRAINT DOM_RECURSO_3D__TIPO_RECURSO CHECK (
        tipo_recurso IN ('Modelo 3D', 'Reconstruccion Historica', 'Guia Flotante', 'Audiovisual Interactivo')
    )
);

-- 11. PUNTO_ANCLAJE_RA
CREATE TABLE Punto_Anclaje_RA (
    id_anclaje         INTEGER GENERATED BY DEFAULT AS IDENTITY,
    latitud            NUMERIC(9,6) NOT NULL,
    longitud           NUMERIC(9,6) NOT NULL,
    altitud_suelo      NUMERIC(8,2) NOT NULL,
    azimut             NUMERIC(6,2) NOT NULL,
    inclinacion        NUMERIC(5,2) NOT NULL,
    rotacion           NUMERIC(6,2) NOT NULL,
    radio_activacion_m NUMERIC(8,2) NOT NULL,
    escala             NUMERIC(6,3) NOT NULL,
    hipervinculo_info  VARCHAR(300) NOT NULL,
    cod_estado         VARCHAR(6)   NOT NULL,
    cod_municipio      VARCHAR(10)  NOT NULL,
    cod_parroquia      VARCHAR(10)  NOT NULL,
    nombre_hito        VARCHAR(150) NOT NULL,
    cod_recurso_3d     VARCHAR(40)  NOT NULL,
    CONSTRAINT PK_PUNTO_ANCLAJE_RA PRIMARY KEY (id_anclaje),
    CONSTRAINT AK_PUNTO_ANCLAJE_RA_COORD UNIQUE (
        cod_estado, cod_municipio, cod_parroquia, nombre_hito,
        cod_recurso_3d, latitud, longitud, altitud_suelo
    ),
    CONSTRAINT FK_PUNTO_ANCLAJE_RA_HITO_TURISTICO FOREIGN KEY (cod_estado, cod_municipio, cod_parroquia, nombre_hito)
        REFERENCES Hito_Turistico (cod_estado, cod_municipio, cod_parroquia, nombre_hito)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT FK_PUNTO_ANCLAJE_RA_RECURSO_3D FOREIGN KEY (cod_recurso_3d)
        REFERENCES Recurso_3D (cod_recurso_3d)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT DOM_PUNTO_ANCLAJE_RA__LATITUD CHECK (latitud BETWEEN -90 AND 90),
    CONSTRAINT DOM_PUNTO_ANCLAJE_RA__LONGITUD CHECK (longitud BETWEEN -180 AND 180),
    CONSTRAINT DOM_PUNTO_ANCLAJE_RA__ALTITUD_SUELO CHECK (altitud_suelo >= 0),
    CONSTRAINT DOM_PUNTO_ANCLAJE_RA__AZIMUT CHECK (azimut >= 0 AND azimut < 360),
    CONSTRAINT DOM_PUNTO_ANCLAJE_RA__INCLINACION CHECK (inclinacion BETWEEN -90 AND 90),
    CONSTRAINT DOM_PUNTO_ANCLAJE_RA__ROTACION CHECK (rotacion >= 0 AND rotacion < 360),
    CONSTRAINT DOM_PUNTO_ANCLAJE_RA__RADIO_ACTIVACION_M CHECK (radio_activacion_m > 0),
    CONSTRAINT DOM_PUNTO_ANCLAJE_RA__ESCALA CHECK (escala > 0),
    CONSTRAINT DOM_PUNTO_ANCLAJE_RA__HIPERVINCULO_INFO CHECK (TRIM(hipervinculo_info) <> '')
);
