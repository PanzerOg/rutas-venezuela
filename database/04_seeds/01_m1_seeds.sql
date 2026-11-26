-- ============================================================================
-- Archivo: 04_seeds/01_m1_seeds.sql
-- Módulo: Módulo 1 - Territorio, Hitos Turísticos y Realidad Aumentada
-- Autor responsable: José Alejandro Montes de Oca Tineo - C.I. 31.066.053
-- Descripción: Carga inicial realista del contexto turístico y patrimonial
--              venezolano (homonimias territoriales reales, hitos en múltiples
--              estados operativos/conservación, duplicidad 3D, horarios,
--              eventos y anclajes de Realidad Aumentada).
-- ============================================================================

BEGIN;

-- 1. ESTADOS (10 entidades federales representativas)
INSERT INTO Estado (cod_estado, nombre_estado) VALUES
('DC', 'Distrito Capital'),
('MI', 'Miranda'),
('FA', 'Falcon'),
('ME', 'Merida'),
('NE', 'Nueva Esparta'),
('ZU', 'Zulia'),
('SU', 'Sucre'),
('AR', 'Aragua'),
('BO', 'Bolivar'),
('BA', 'Barinas');

-- 2. MUNICIPIOS (incluye homonimias reales exigidas: múltiples Sucre y Libertador)
INSERT INTO Municipio (cod_estado, cod_municipio, nombre_municipio) VALUES
('DC', 'LIB', 'Libertador'),
('MI', 'CHA', 'Chacao'),
('MI', 'SUC', 'Sucre'),
('MI', 'BAR', 'Baruta'),
('MI', 'BRZ', 'Brion'),
('FA', 'MIR', 'Miranda'),
('FA', 'SUC', 'Sucre'),
('ME', 'LIB', 'Libertador'),
('ME', 'SUC', 'Sucre'),
('NE', 'MAN', 'Maneiro'),
('NE', 'ARI', 'Arismendi'),
('ZU', 'MAR', 'Maracaibo'),
('ZU', 'SUC', 'Sucre'),
('SU', 'SUC', 'Sucre'),
('SU', 'BER', 'Bermudez'),
('AR', 'LIB', 'Libertador'),
('AR', 'GIR', 'Girardot'),
('BO', 'ANG', 'Angostura del Orinoco'),
('BA', 'BOL', 'Bolivar');

-- 3. PARROQUIAS (incluye múltiples Parroquias San José y parroquias patrimoniales reales)
INSERT INTO Parroquia (cod_estado, cod_municipio, cod_parroquia, nombre_parroquia, tipo_demarcacion) VALUES
('DC', 'LIB', 'CAT', 'Catedral', 'Urbana'),
('DC', 'LIB', 'ALT', 'Altagracia', 'Urbana'),
('DC', 'LIB', 'SJO', 'San Jose', 'Urbana'),
('DC', 'LIB', 'SAG', 'San Agustin', 'Urbana'),
('DC', 'LIB', 'REC', 'El Recreo', 'Urbana'),
('MI', 'CHA', 'CHA', 'Chacao', 'Urbana'),
('MI', 'SUC', 'PET', 'Petare', 'Urbana'),
('MI', 'SUC', 'SJO', 'San Jose', 'Mixta'),
('MI', 'BAR', 'ELC', 'El Cafetal', 'Urbana'),
('MI', 'BRZ', 'HIG', 'Higuerote', 'Mixta'),
('FA', 'MIR', 'SAN', 'San Antonio', 'Urbana'),
('FA', 'MIR', 'SAG', 'Santa Ana', 'Urbana'),
('ME', 'LIB', 'ELL', 'El Llano', 'Urbana'),
('ME', 'LIB', 'MLL', 'Milla', 'Urbana'),
('NE', 'MAN', 'PAM', 'Pampatar', 'Urbana'),
('NE', 'ARI', 'ASU', 'La Asuncion', 'Urbana'),
('ZU', 'MAR', 'SLU', 'Santa Lucia', 'Urbana'),
('ZU', 'MAR', 'CHI', 'Chiquinquira', 'Urbana'),
('ZU', 'SUC', 'SJO', 'San Jose', 'Rural'),
('SU', 'SUC', 'SIN', 'Santa Ines', 'Urbana'),
('AR', 'LIB', 'SJO', 'San Jose', 'Mixta'),
('AR', 'GIR', 'CHO', 'Choroni', 'Rural'),
('BO', 'ANG', 'CAT', 'Catedral', 'Urbana'),
('BA', 'BOL', 'BAR', 'Barinitas', 'Rural');

-- 4. CATEGORÍAS PATRIMONIALES Y CULTURALES (8 categorías)
INSERT INTO Categoria (id_categoria, nombre_categoria, descripcion) VALUES
(1, 'Monumento Historico', 'Bienes inmuebles y sitios declarados patrimonio historico nacional o regional.'),
(2, 'Museo y Galeria', 'Espacios expositivos dedicados a las artes, historia, ciencia y memoria cultural.'),
(3, 'Plaza y Espacio Publico', 'Plazas fundacionales, paseos urbanos, bulevares y puntos de encuentro ciudadano.'),
(4, 'Patrimonio Natural', 'Parques nacionales, cuevas, miradores naturales, costas y formaciones ecologicas.'),
(5, 'Mercado Tradicional', 'Mercados populares, ferias artesanales y centros gastronomicos autoctonos.'),
(6, 'Arte Urbano y Mural', 'Obras monumentales, cinetismo, murales y esculturas en espacio publico.'),
(7, 'Edificio Institucional', 'Sedes historicas de gobierno, palacios legislativos y academias.'),
(8, 'Fortificacion Colonial', 'Castillos, fortines y estructuras defensivas del periodo colonial.');

-- 5. RESERVA DE CLAVES SUSTITUTAS DE CATEGORÍA U PARA LOS 18 HITOS DE M1 (IDs 1..18)
INSERT INTO Punto_Itinerario (id_punto_itin)
SELECT gs FROM generate_series(1, 18) AS gs;

INSERT INTO Elemento_Afectable (id_elem_afectable)
SELECT gs FROM generate_series(1, 18) AS gs;

INSERT INTO Objeto_Evaluable (id_obj_evaluable)
SELECT gs FROM generate_series(1, 18) AS gs;

INSERT INTO Elemento_Servicio (id_elem_servicio)
SELECT gs FROM generate_series(1, 18) AS gs;

-- 6. HITOS TURÍSTICOS (18 hitos reales en Venezuela)
--    Incluye:
--    * Homonimia: 'Plaza Bolivar' en DC/LIB/CAT, BO/ANG/CAT y ME/LIB/ELL
--    * Duplicidad espacial 3D exacta: IDs 6 y 7 comparten exactamente (10.498120, -66.900150, 882.00)
--    * Los 4 estados operativos y 5 niveles de conservacion
--    * Monumentos historicos con libre_acceso = FALSE para la Consulta Patrimonial
INSERT INTO Hito_Turistico (
    cod_estado, cod_municipio, cod_parroquia, nombre_hito, descripcion,
    estado_operativo, libre_acceso, estado_conservacion,
    latitud, longitud, elevacion,
    id_punto_itin, id_elem_afectable, id_obj_evaluable, id_elem_servicio
) VALUES
('DC', 'LIB', 'CAT', 'Casa Natal del Libertador',
 'Casona colonial del siglo XVIII donde nacio Simon Bolivar en 1783, museo patrimonial con murales de Tito Salas.',
 'Disponible', FALSE, 'Optimo',
 10.506098, -66.914602, 900.50, 1, 1, 1, 1),

('DC', 'LIB', 'CAT', 'Plaza Bolivar',
 'Corazon fundacional de Caracas rodeado por la Catedral, el Palacio Arzobispal y la estatua ecuestre de 1874.',
 'Disponible', TRUE, 'Bueno',
 10.506380, -66.914650, 902.00, 2, 2, 2, 2),

('DC', 'LIB', 'ALT', 'Panteon Nacional',
 'Mausoleo nacional donde reposan los restos del Libertador y heroes de la independencia venezolana.',
 'Disponible', FALSE, 'Optimo',
 10.511780, -66.911450, 922.40, 3, 3, 3, 3),

('DC', 'LIB', 'SJO', 'Museo de Ciencias de Caracas',
 'Edificio neoclasico en Los Caobos con colecciones antropologicas, paleontologicas y de biodiversidad.',
 'En restauracion', FALSE, 'Regular',
 10.499820, -66.898110, 886.00, 4, 4, 4, 4),

('DC', 'LIB', 'SAG', 'Teatro Teresa Carreno',
 'Complejo cultural brutalista emblematico para opera, ballet y conciertos sinfonicos.',
 'Disponible', FALSE, 'Bueno',
 10.499150, -66.897950, 884.00, 5, 5, 5, 5),

-- Duplicidad espacial 3D intencional (mismas coordenadas en distinto nivel del mismo complejo):
('DC', 'LIB', 'SAG', 'Museo de Arte Contemporaneo de Caracas',
 'Salas expositivas en nivel plaza de Parque Central con coleccion de arte cinetico y moderno.',
 'Disponible', FALSE, 'Regular',
 10.498120, -66.900150, 882.00, 6, 6, 6, 6),

('DC', 'LIB', 'SAG', 'Mirador Torre Oeste Parque Central',
 'Plataforma panoramica urbana compartiendo coordenada estructural exacta con el edificio del museo.',
 'Clausurado temporalmente', FALSE, 'Deteriorado',
 10.498120, -66.900150, 882.00, 7, 7, 7, 7),

('DC', 'LIB', 'REC', 'Paseo Los Proceres',
 'Conjunto monumental conmemorativo con fuentes, obeliscos y esculturas alegoricas a la gesta emancipadora.',
 'Disponible', TRUE, 'Optimo',
 10.479340, -66.901220, 875.00, 8, 8, 8, 8),

('MI', 'CHA', 'CHA', 'Centro Cultural Chacao',
 'Espacio de artes escenicas, teatro, exposiciones y encuentros culturales en el eje este capitalino.',
 'Disponible', FALSE, 'Optimo',
 10.493280, -66.854810, 898.00, 9, 9, 9, 9),

('MI', 'SUC', 'PET', 'Centro Historico de Petare',
 'Casco colonial de calles empedradas, Iglesia del Dulce Nombre de Jesus y casas patrimoniales del siglo XVII.',
 'Disponible', TRUE, 'Regular',
 10.478500, -66.807400, 865.00, 10, 10, 10, 10),

('FA', 'MIR', 'SAN', 'Cruz de San Clemente',
 'Cruz de madera de cuji frente a la primera iglesia fundada en Tierra Firme en 1527 en Santa Ana de Coro.',
 'Disponible', TRUE, 'Optimo',
 11.409420, -69.678910, 21.50, 11, 11, 11, 11),

('FA', 'MIR', 'SAG', 'Medanos de Coro',
 'Paisaje desertico de dunas moviles costeras declarado Parque Nacional al norte de la ciudad de Coro.',
 'Disponible', TRUE, 'Optimo',
 11.441200, -69.669500, 18.00, 12, 12, 12, 12),

('NE', 'MAN', 'PAM', 'Castillo San Carlos de Borromeo',
 'Fortificacion colonial costera construida entre 1662 y 1684 para resguardar la bahia de Pampatar.',
 'En restauracion', FALSE, 'Deteriorado',
 10.996840, -63.796320, 8.50, 13, 13, 13, 13),

('ME', 'LIB', 'ELL', 'Plaza Bolivar',
 'Plaza mayor de Merida enmarcada por la Catedral Metropolitana, el Rectorado de la ULA y la Sierra Nevada.',
 'Disponible', TRUE, 'Optimo',
 8.597780, -71.144610, 1630.00, 14, 14, 14, 14),

('ME', 'LIB', 'MLL', 'Mercado Principal de Merida',
 'Centro gastronomico y artesanal andino de tres niveles con dulceria tipica, fresas y textileria.',
 'Disponible', TRUE, 'Bueno',
 8.587210, -71.158300, 1595.00, 15, 15, 15, 15),

('ZU', 'MAR', 'SLU', 'Calle Carabobo',
 'Corredor historico marabino de fachadas policromadas, galerias populares y tradiciones gaiteras.',
 'Disponible', TRUE, 'Bueno',
 10.644200, -71.608800, 12.00, 16, 16, 16, 16),

('SU', 'SUC', 'SIN', 'Castillo San Antonio de la Eminencia',
 'Fortaleza en estrella de 1659 sobre el cerro Pan de Azucar con vista panoramica del Golfo de Cariaco.',
 'Disponible', FALSE, 'Regular',
 10.464820, -64.173150, 74.00, 17, 17, 17, 17),

('BO', 'ANG', 'CAT', 'Plaza Bolivar',
 'Antigua Plaza Mayor de Angostura rodeada por la Casa del Congreso de Angostura y la Catedral de Ciudad Bolivar.',
 'Cerrado permanentemente', TRUE, 'Critico',
 8.144920, -63.549810, 48.00, 18, 18, 18, 18);

-- 7. CLASIFICACIÓN DE HITOS POR CATEGORÍA (HITO_CATEGORIA)
INSERT INTO Hito_Categoria (cod_estado, cod_municipio, cod_parroquia, nombre_hito, id_categoria) VALUES
('DC', 'LIB', 'CAT', 'Casa Natal del Libertador', 1),
('DC', 'LIB', 'CAT', 'Casa Natal del Libertador', 2),
('DC', 'LIB', 'CAT', 'Plaza Bolivar', 1),
('DC', 'LIB', 'CAT', 'Plaza Bolivar', 3),
('DC', 'LIB', 'ALT', 'Panteon Nacional', 1),
('DC', 'LIB', 'ALT', 'Panteon Nacional', 7),
('DC', 'LIB', 'SJO', 'Museo de Ciencias de Caracas', 2),
('DC', 'LIB', 'SJO', 'Museo de Ciencias de Caracas', 1),
('DC', 'LIB', 'SAG', 'Teatro Teresa Carreno', 2),
('DC', 'LIB', 'SAG', 'Teatro Teresa Carreno', 6),
('DC', 'LIB', 'SAG', 'Museo de Arte Contemporaneo de Caracas', 2),
('DC', 'LIB', 'SAG', 'Museo de Arte Contemporaneo de Caracas', 6),
('DC', 'LIB', 'SAG', 'Mirador Torre Oeste Parque Central', 3),
('DC', 'LIB', 'REC', 'Paseo Los Proceres', 1),
('DC', 'LIB', 'REC', 'Paseo Los Proceres', 3),
('MI', 'CHA', 'CHA', 'Centro Cultural Chacao', 2),
('MI', 'CHA', 'CHA', 'Centro Cultural Chacao', 6),
('MI', 'SUC', 'PET', 'Centro Historico de Petare', 1),
('MI', 'SUC', 'PET', 'Centro Historico de Petare', 3),
('FA', 'MIR', 'SAN', 'Cruz de San Clemente', 1),
('FA', 'MIR', 'SAG', 'Medanos de Coro', 4),
('NE', 'MAN', 'PAM', 'Castillo San Carlos de Borromeo', 1),
('NE', 'MAN', 'PAM', 'Castillo San Carlos de Borromeo', 8),
('ME', 'LIB', 'ELL', 'Plaza Bolivar', 1),
('ME', 'LIB', 'ELL', 'Plaza Bolivar', 3),
('ME', 'LIB', 'MLL', 'Mercado Principal de Merida', 5),
('ZU', 'MAR', 'SLU', 'Calle Carabobo', 1),
('ZU', 'MAR', 'SLU', 'Calle Carabobo', 6),
('SU', 'SUC', 'SIN', 'Castillo San Antonio de la Eminencia', 1),
('SU', 'SUC', 'SIN', 'Castillo San Antonio de la Eminencia', 8),
('BO', 'ANG', 'CAT', 'Plaza Bolivar', 1),
('BO', 'ANG', 'CAT', 'Plaza Bolivar', 3);

-- 8. HORARIOS DE VISITA (HORARIO_HITO)
--    Obligatorios para todo hito con libre_acceso = FALSE (RR-M1-02)
INSERT INTO Horario_Hito (cod_estado, cod_municipio, cod_parroquia, nombre_hito, dia_semana, hora_apertura, hora_cierre) VALUES
-- Casa Natal del Libertador (doble turno y fin de semana)
('DC', 'LIB', 'CAT', 'Casa Natal del Libertador', 'Martes',    '09:00', '12:30'),
('DC', 'LIB', 'CAT', 'Casa Natal del Libertador', 'Martes',    '13:30', '16:30'),
('DC', 'LIB', 'CAT', 'Casa Natal del Libertador', 'Miercoles', '09:00', '16:30'),
('DC', 'LIB', 'CAT', 'Casa Natal del Libertador', 'Jueves',    '09:00', '16:30'),
('DC', 'LIB', 'CAT', 'Casa Natal del Libertador', 'Viernes',   '09:00', '16:30'),
('DC', 'LIB', 'CAT', 'Casa Natal del Libertador', 'Sabado',    '10:00', '16:00'),
('DC', 'LIB', 'CAT', 'Casa Natal del Libertador', 'Domingo',   '10:00', '15:00'),
-- Panteon Nacional (monumento historico no libre acceso, abierto fines de semana)
('DC', 'LIB', 'ALT', 'Panteon Nacional', 'Martes',    '09:00', '16:00'),
('DC', 'LIB', 'ALT', 'Panteon Nacional', 'Miercoles', '09:00', '16:00'),
('DC', 'LIB', 'ALT', 'Panteon Nacional', 'Jueves',    '09:00', '16:00'),
('DC', 'LIB', 'ALT', 'Panteon Nacional', 'Viernes',   '09:00', '16:00'),
('DC', 'LIB', 'ALT', 'Panteon Nacional', 'Sabado',    '09:30', '16:00'),
('DC', 'LIB', 'ALT', 'Panteon Nacional', 'Domingo',   '09:30', '15:30'),
-- Museo de Ciencias
('DC', 'LIB', 'SJO', 'Museo de Ciencias de Caracas', 'Jueves',  '10:00', '15:00'),
('DC', 'LIB', 'SJO', 'Museo de Ciencias de Caracas', 'Sabado',  '10:00', '16:00'),
-- Teatro Teresa Carreno
('DC', 'LIB', 'SAG', 'Teatro Teresa Carreno', 'Viernes', '14:00', '21:00'),
('DC', 'LIB', 'SAG', 'Teatro Teresa Carreno', 'Sabado',  '11:00', '21:30'),
('DC', 'LIB', 'SAG', 'Teatro Teresa Carreno', 'Domingo', '11:00', '19:00'),
-- Museo de Arte Contemporaneo
('DC', 'LIB', 'SAG', 'Museo de Arte Contemporaneo de Caracas', 'Miercoles', '10:00', '16:00'),
('DC', 'LIB', 'SAG', 'Museo de Arte Contemporaneo de Caracas', 'Jueves',    '10:00', '16:00'),
('DC', 'LIB', 'SAG', 'Museo de Arte Contemporaneo de Caracas', 'Sabado',    '10:00', '17:00'),
-- Mirador Torre Oeste Parque Central (libre_acceso = FALSE)
('DC', 'LIB', 'SAG', 'Mirador Torre Oeste Parque Central', 'Sabado',  '10:00', '18:00'),
('DC', 'LIB', 'SAG', 'Mirador Torre Oeste Parque Central', 'Domingo', '10:00', '17:00'),
-- Centro Cultural Chacao
('MI', 'CHA', 'CHA', 'Centro Cultural Chacao', 'Miercoles', '11:00', '19:00'),
('MI', 'CHA', 'CHA', 'Centro Cultural Chacao', 'Jueves',    '11:00', '20:00'),
('MI', 'CHA', 'CHA', 'Centro Cultural Chacao', 'Viernes',   '11:00', '21:00'),
('MI', 'CHA', 'CHA', 'Centro Cultural Chacao', 'Sabado',    '10:00', '21:00'),
('MI', 'CHA', 'CHA', 'Centro Cultural Chacao', 'Domingo',   '10:00', '18:00'),
-- Castillo San Carlos de Borromeo (En restauracion, horario reducido)
('NE', 'MAN', 'PAM', 'Castillo San Carlos de Borromeo', 'Sabado',  '09:00', '14:00'),
('NE', 'MAN', 'PAM', 'Castillo San Carlos de Borromeo', 'Domingo', '09:00', '14:00'),
-- Castillo San Antonio de la Eminencia (Monumento Historico disponible fin de semana)
('SU', 'SUC', 'SIN', 'Castillo San Antonio de la Eminencia', 'Viernes', '09:00', '17:00'),
('SU', 'SUC', 'SIN', 'Castillo San Antonio de la Eminencia', 'Sabado',  '09:00', '17:30'),
('SU', 'SUC', 'SIN', 'Castillo San Antonio de la Eminencia', 'Domingo', '09:00', '16:30'),
-- Mercado Principal de Merida (libre_acceso = TRUE con horario referencial)
('ME', 'LIB', 'MLL', 'Mercado Principal de Merida', 'Sabado',  '07:00', '17:00'),
('ME', 'LIB', 'MLL', 'Mercado Principal de Merida', 'Domingo', '07:00', '16:00');

-- 9. EVENTOS Y ACTIVIDADES CULTURALES + SEDES
INSERT INTO Evento_Actividad (id_evento, titulo, descripcion, tipo_evento, fecha_inicio, fecha_fin) VALUES
(1, 'Recorrido Nocturno por el Casco Historico',
 'Visita guiada teatralizada sobre la historia de Caracas colonial entre la Casa Natal y la Plaza Bolivar.',
 'Visita Guiada', '2026-11-28 17:30:00', '2026-11-28 20:30:00'),
(2, 'Ciclo Sinfonico Juvenil de Venezuela',
 'Concierto extraordinario de repertorio latinoamericano en la Sala Rios Reyna.',
 'Concierto', '2026-12-05 18:00:00', '2026-12-05 20:30:00'),
(3, 'Muestra de Cinetismo y Cruz-Diez',
 'Exhibicion interactiva de color, luz y obras cineticas en espacios museisticos capitalinos.',
 'Exposicion', '2026-11-20 10:00:00', '2026-12-30 17:00:00'),
(4, 'Festival de Tradiciones Falconianas en Coro',
 'Encuentro de artesanos, gastronomia de chivo y musica tradicional junto a la Cruz de San Clemente.',
 'Festival Cultural', '2026-12-12 09:00:00', '2026-12-14 21:00:00'),
(5, 'Jornada Astronomica Nocturna en Los Medanos',
 'Observacion guiada de constelaciones y senderismo nocturno responsable sobre las dunas.',
 'Ecoturismo', '2026-12-19 18:30:00', '2026-12-19 22:30:00'),
(6, 'Feria Gastronomica y Dulceria Andina',
 'Degustacion de pastelitos, pizca andina y dulces abrillantados con productores locales.',
 'Feria Gastronomica', '2026-12-06 08:00:00', '2026-12-06 16:00:00'),
(7, 'Tarde de Gaitas y Fachadas de Santa Lucia',
 'Recorrido musical y fotografico por el corredor patrimonial de la Calle Carabobo.',
 'Festival Musical', '2026-12-11 16:00:00', '2026-12-11 21:00:00'),
(8, 'Atardecer Historico sobre el Golfo de Cariaco',
 'Narracion historica de fortificaciones orientales y musica tradicional sucrense.',
 'Charla Patrimonial', '2026-12-20 15:30:00', '2026-12-20 18:30:00');

INSERT INTO Sede_De_Evento (id_evento, cod_estado, cod_municipio, cod_parroquia, nombre_hito) VALUES
(1, 'DC', 'LIB', 'CAT', 'Casa Natal del Libertador'),
(1, 'DC', 'LIB', 'CAT', 'Plaza Bolivar'),
(2, 'DC', 'LIB', 'SAG', 'Teatro Teresa Carreno'),
(3, 'DC', 'LIB', 'SAG', 'Museo de Arte Contemporaneo de Caracas'),
(3, 'MI', 'CHA', 'CHA', 'Centro Cultural Chacao'),
(4, 'FA', 'MIR', 'SAN', 'Cruz de San Clemente'),
(5, 'FA', 'MIR', 'SAG', 'Medanos de Coro'),
(6, 'ME', 'LIB', 'MLL', 'Mercado Principal de Merida'),
(7, 'ZU', 'MAR', 'SLU', 'Calle Carabobo'),
(8, 'SU', 'SUC', 'SIN', 'Castillo San Antonio de la Eminencia');

-- 10. RECURSOS 3D Y PUNTOS DE ANCLAJE DE REALIDAD AUMENTADA
--     Un mismo recurso 3D puede proyectarse en múltiples puntos de anclaje con distinta orientación
INSERT INTO Recurso_3D (cod_recurso_3d, tipo_recurso, descripcion) VALUES
('MOD3D_CASONA_1783', 'Reconstruccion Historica', 'Reconstruccion 3D de la fachada original de la Casa Natal de 1783.'),
('MOD3D_ESTATUA_BOLIVAR', 'Modelo 3D', 'Escultura ecuestre interactiva con capas informativas de 1874.'),
('MOD3D_PANTEON_NAVE', 'Reconstruccion Historica', 'Vista en rayos X de la nave central y arca del Panteon Nacional.'),
('GUIA_PLAZA_COLONIAL', 'Guia Flotante', 'Panel flotante de orientacion hacia hitos historicos cercanos.'),
('MOD3D_BRUTALISMO_TTC', 'Audiovisual Interactivo', 'Maqueta animada acustica de la Sala Rios Reyna.'),
('MOD3D_CINETISMO_CRUZ', 'Modelo 3D', 'Instalacion cinetica virtual de induccion cromatica.'),
('MOD3D_CASTILLO_BALUARTE', 'Reconstruccion Historica', 'Reconstruccion defensiva de baluartes coloniales con canones del siglo XVII.'),
('GUIA_CORO_1527', 'Guia Flotante', 'Flechas y cronologia flotante de la fundacion de Santa Ana de Coro.');

INSERT INTO Punto_Anclaje_RA (
    id_anclaje, latitud, longitud, altitud_suelo, azimut, inclinacion, rotacion,
    radio_activacion_m, escala, hipervinculo_info,
    cod_estado, cod_municipio, cod_parroquia, nombre_hito, cod_recurso_3d
) VALUES
(1,  10.506105, -66.914590, 1.80, 135.00,  5.00,  0.00, 180.00, 1.000, 'https://rutasvenezuela.ve/ar/casa-natal-fachada',
 'DC', 'LIB', 'CAT', 'Casa Natal del Libertador', 'MOD3D_CASONA_1783'),
(2,  10.506150, -66.914620, 2.50,  45.00,  0.00, 15.00, 150.00, 0.850, 'https://rutasvenezuela.ve/ar/casa-natal-guia',
 'DC', 'LIB', 'CAT', 'Casa Natal del Libertador', 'GUIA_PLAZA_COLONIAL'),
(3,  10.506385, -66.914645, 3.20, 180.00, -5.00,  0.00, 220.00, 1.250, 'https://rutasvenezuela.ve/ar/plaza-bolivar-ccs',
 'DC', 'LIB', 'CAT', 'Plaza Bolivar', 'MOD3D_ESTATUA_BOLIVAR'),
(4,  10.506410, -66.914690, 2.00,  90.00,  0.00,  0.00, 250.00, 1.000, 'https://rutasvenezuela.ve/ar/guia-casco-caracas',
 'DC', 'LIB', 'CAT', 'Plaza Bolivar', 'GUIA_PLAZA_COLONIAL'),
(5,  10.511760, -66.911440, 4.00,  10.00, 12.00,  0.00, 200.00, 1.400, 'https://rutasvenezuela.ve/ar/panteon-nave',
 'DC', 'LIB', 'ALT', 'Panteon Nacional', 'MOD3D_PANTEON_NAVE'),
(6,  10.499160, -66.897940, 2.20, 225.00,  8.00,  0.00, 200.00, 1.100, 'https://rutasvenezuela.ve/ar/teresa-carreno',
 'DC', 'LIB', 'SAG', 'Teatro Teresa Carreno', 'MOD3D_BRUTALISMO_TTC'),
(7,  10.498125, -66.900155, 1.50, 310.00,  0.00, 20.00, 160.00, 1.000, 'https://rutasvenezuela.ve/ar/macc-cinetismo',
 'DC', 'LIB', 'SAG', 'Museo de Arte Contemporaneo de Caracas', 'MOD3D_CINETISMO_CRUZ'),
(8,  10.493285, -66.854805, 1.80, 120.00,  0.00, 45.00, 120.00, 0.900, 'https://rutasvenezuela.ve/ar/chacao-cinetismo',
 'MI', 'CHA', 'CHA', 'Centro Cultural Chacao', 'MOD3D_CINETISMO_CRUZ'),
(9,  11.409425, -69.678900, 2.00,  60.00,  5.00,  0.00, 140.00, 1.000, 'https://rutasvenezuela.ve/ar/coro-cruz-1527',
 'FA', 'MIR', 'SAN', 'Cruz de San Clemente', 'GUIA_CORO_1527'),
(10, 10.996850, -63.796310, 3.50, 270.00, -3.00,  0.00, 240.00, 1.500, 'https://rutasvenezuela.ve/ar/borromeo-baluarte',
 'NE', 'MAN', 'PAM', 'Castillo San Carlos de Borromeo', 'MOD3D_CASTILLO_BALUARTE'),
(11,  8.597790, -71.144600, 2.50,  15.00,  0.00,  0.00, 200.00, 1.150, 'https://rutasvenezuela.ve/ar/plaza-bolivar-merida',
 'ME', 'LIB', 'ELL', 'Plaza Bolivar', 'MOD3D_ESTATUA_BOLIVAR'),
(12, 10.464830, -64.173140, 4.50, 195.00, -8.00,  0.00, 260.00, 1.350, 'https://rutasvenezuela.ve/ar/eminencia-baluarte',
 'SU', 'SUC', 'SIN', 'Castillo San Antonio de la Eminencia', 'MOD3D_CASTILLO_BALUARTE');

-- 11. SINCRONIZACIÓN DE SECUENCIAS DE IDENTIDAD (sin subconsultas en SELECT)
SELECT setval(pg_get_serial_sequence('punto_itinerario', 'id_punto_itin'), COALESCE(MAX(id_punto_itin), 1)) FROM Punto_Itinerario;
SELECT setval(pg_get_serial_sequence('elemento_afectable', 'id_elem_afectable'), COALESCE(MAX(id_elem_afectable), 1)) FROM Elemento_Afectable;
SELECT setval(pg_get_serial_sequence('objeto_evaluable', 'id_obj_evaluable'), COALESCE(MAX(id_obj_evaluable), 1)) FROM Objeto_Evaluable;
SELECT setval(pg_get_serial_sequence('elemento_servicio', 'id_elem_servicio'), COALESCE(MAX(id_elem_servicio), 1)) FROM Elemento_Servicio;
SELECT setval(pg_get_serial_sequence('categoria', 'id_categoria'), COALESCE(MAX(id_categoria), 1)) FROM Categoria;
SELECT setval(pg_get_serial_sequence('evento_actividad', 'id_evento'), COALESCE(MAX(id_evento), 1)) FROM Evento_Actividad;
SELECT setval(pg_get_serial_sequence('punto_anclaje_ra', 'id_anclaje'), COALESCE(MAX(id_anclaje), 1)) FROM Punto_Anclaje_RA;

COMMIT;
