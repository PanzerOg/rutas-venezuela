-- Módulo 3 · Autor responsable: Leonardo Enrique Chacón Agraz - C.I. 31.895.402
-- Perfiles ficticios de demostración. Contraseña común de prueba: RutasDemo2026!
BEGIN;

-- El ZIP inicial no contiene la carga de M1. En el repositorio integrado esta
-- sección se omite automáticamente si M1 ya cargó sus hitos.
DO $$
DECLARE
    r_hito RECORD;
    v_categoria INTEGER;
    v_punto INTEGER;
    v_afectable INTEGER;
    v_objeto INTEGER;
    v_servicio INTEGER;
BEGIN
    IF EXISTS (SELECT 1 FROM Hito_Turistico) THEN
        RETURN;
    END IF;
    INSERT INTO Estado (cod_estado,nombre_estado) VALUES ('DC','Distrito Capital'),('MER','Mérida'),('MIR','Miranda')
        ON CONFLICT DO NOTHING;
    INSERT INTO Municipio (cod_estado,cod_municipio,nombre_municipio)
        VALUES ('DC','LIB','Libertador'),('MER','LIB','Libertador'),('MIR','CHA','Chacao') ON CONFLICT DO NOTHING;
    INSERT INTO Parroquia (cod_estado,cod_municipio,cod_parroquia,nombre_parroquia,tipo_demarcacion)
        VALUES ('DC','LIB','CAT','Catedral','Urbana'),('MER','LIB','SAR','Sagrario','Urbana'),
               ('MIR','CHA','CHA','Chacao','Urbana') ON CONFLICT DO NOTHING;
    INSERT INTO Categoria (nombre_categoria,descripcion) VALUES ('Monumento Historico','Patrimonio cultural')
        ON CONFLICT (nombre_categoria) DO UPDATE SET nombre_categoria = EXCLUDED.nombre_categoria
        RETURNING id_categoria INTO v_categoria;
    FOR r_hito IN
        SELECT unnest(ARRAY['DC','DC','MER','MER','MIR','MIR']) AS estado,
               unnest(ARRAY['LIB','LIB','LIB','LIB','CHA','CHA']) AS municipio,
               unnest(ARRAY['CAT','CAT','SAR','SAR','CHA','CHA']) AS parroquia,
               unnest(ARRAY['Casa Natal del Libertador','Museo Sacro de Caracas','Museo de Arte Colonial',
                            'Centro Cultural Tulio Febres Cordero','Casa de la Cultura de Chacao',
                            'Centro Cultural Chacao']) AS nombre,
               unnest(ARRAY[10.505,10.507,8.597,8.595,10.496,10.499]) AS lat,
               unnest(ARRAY[-66.915,-66.914,-71.144,-71.145,-66.849,-66.853]) AS lon,
               unnest(ARRAY[900,900,1630,1630,865,865]) AS elevacion
    LOOP
        INSERT INTO Punto_Itinerario DEFAULT VALUES RETURNING id_punto_itin INTO v_punto;
        INSERT INTO Elemento_Afectable DEFAULT VALUES RETURNING id_elem_afectable INTO v_afectable;
        INSERT INTO Objeto_Evaluable DEFAULT VALUES RETURNING id_obj_evaluable INTO v_objeto;
        INSERT INTO Elemento_Servicio DEFAULT VALUES RETURNING id_elem_servicio INTO v_servicio;
        INSERT INTO Hito_Turistico (
            cod_estado,cod_municipio,cod_parroquia,nombre_hito,descripcion,estado_operativo,libre_acceso,
            estado_conservacion,latitud,longitud,elevacion,id_punto_itin,id_elem_afectable,id_obj_evaluable,id_elem_servicio
        ) VALUES (r_hito.estado,r_hito.municipio,r_hito.parroquia,r_hito.nombre,'Hito del catálogo de demostración',
            'Disponible',FALSE,'Bueno',r_hito.lat,r_hito.lon,r_hito.elevacion,v_punto,v_afectable,v_objeto,v_servicio);
        INSERT INTO Hito_Categoria VALUES (r_hito.estado,r_hito.municipio,r_hito.parroquia,r_hito.nombre,v_categoria);
        INSERT INTO Horario_Hito
        SELECT r_hito.estado,r_hito.municipio,r_hito.parroquia,r_hito.nombre, dia,TIME '08:00',TIME '18:00'
        FROM unnest(ARRAY['Lunes','Martes','Miercoles','Jueves','Viernes','Sabado','Domingo']) AS dias(dia);
    END LOOP;
END;
$$;

DO $$
DECLARE
    v_hash CONSTANT TEXT := 'pbkdf2_sha256:600000:cdfe4868b1834cee6927b04af11930c4b0:9bb15b0d7a99170c9cd01c104df092935db400202ca72656a74690cce6f167a0';
    v_usuario INTEGER;
    v_reportante INTEGER;
    v_validador INTEGER;
    v_servicio INTEGER;
    v_nombres TEXT[] := ARRAY['Ana','Marco','Gabriela','Luis','Valeria','Santiago','Paola','Diego'];
    v_apellidos TEXT[] := ARRAY['Suárez','Mendoza','Rivas','Pérez','Andrade','Ferrer','Soto','Reyes'];
    v_comercios TEXT[] := ARRAY['Café Esquina del Sol','Sabores de La Sierra','Cacao del Centro',
                              'Bicicletas del Valle','Posada Entre Nubes','Copas de Miranda'];
    v_entes TEXT[] := ARRAY['Oficina Patrimonial de Caracas','Instituto Cultural de Mérida',
                           'Dirección de Patrimonio de Chacao','Fundación de Rutas Culturales'];
BEGIN
    FOR v_i IN 1..24 LOOP
        INSERT INTO Actor_Usuario (contrasena_hash,tipo_actor) VALUES (v_hash,'Visitante') RETURNING id_usuario INTO v_usuario;
        INSERT INTO Reportante DEFAULT VALUES RETURNING id_reportante INTO v_reportante;
        INSERT INTO Visitante VALUES (v_usuario,
            CASE WHEN v_i <= 20 THEN 'V-' || (90000000 + v_i) ELSE 'DEMO-P' || v_i END,
            CASE WHEN v_i <= 20 THEN 'Cedula' ELSE 'Pasaporte' END,
            v_nombres[(v_i-1)%8+1], v_apellidos[((v_i-1)/3)%8+1],
            CASE WHEN v_i <= 20 THEN 'Venezuela' ELSE 'Colombia' END, 'Español', '000-000-0000',
            (ARRAY['O+','A+','B+','AB-'])[(v_i-1)%4+1], v_reportante);
        IF v_i % 3 = 0 THEN
            INSERT INTO Accesibilidad_Visitante VALUES (v_usuario, (ARRAY['Rampas','Señalización auditiva','Pausas frecuentes'])[(v_i/3)%3+1]);
        END IF;
    END LOOP;

    FOR v_i IN 1..6 LOOP
        INSERT INTO Actor_Usuario (contrasena_hash,tipo_actor) VALUES (v_hash,'Guia') RETURNING id_usuario INTO v_usuario;
        INSERT INTO Reportante DEFAULT VALUES RETURNING id_reportante INTO v_reportante;
        INSERT INTO Validador_Acceso DEFAULT VALUES RETURNING id_validador INTO v_validador;
        INSERT INTO Guia_Turistico VALUES (v_usuario,'RTN-DEMO-' || v_i,'LIC-DEMO-' || v_i,
            'Acreditación ficticia ' || v_i,v_i+2,15+v_i*5,(ARRAY['Caracas','Mérida','Miranda'])[(v_i-1)%3+1],
            v_validador,v_reportante);
        INSERT INTO Especialidad_Guia VALUES (v_usuario,'Patrimonio'),
            (v_usuario,(ARRAY['Senderismo','Arte colonial','Gastronomía local'])[(v_i-1)%3+1]);
        INSERT INTO Idioma_Guia VALUES (v_usuario,'Español'),(v_usuario,CASE WHEN v_i % 2=0 THEN 'Inglés' ELSE 'Portugués' END);

        INSERT INTO Actor_Usuario (contrasena_hash,tipo_actor) VALUES (v_hash,'Comercio') RETURNING id_usuario INTO v_usuario;
        INSERT INTO Elemento_Servicio DEFAULT VALUES RETURNING id_elem_servicio INTO v_servicio;
        INSERT INTO Validador_Acceso DEFAULT VALUES RETURNING id_validador INTO v_validador;
        INSERT INTO Comercio_Aliado (
            id_usuario,rif_comercio,razon_social,categoria_comercial,aforo,nro_permiso_sanitario,
            cuenta_bancaria,id_elem_servicio,id_validador
        ) VALUES (v_usuario, 'J-9900000' || v_i || '-0', v_comercios[v_i],
            (ARRAY['Gastronomía','Alojamiento','Alquiler de equipos'])[(v_i-1)%3+1],
            15+v_i*5,'DEMO-SAN-' || v_i,lpad(v_i::TEXT,20,'0'),v_servicio,v_validador);
        INSERT INTO Horario_Atencion_Comercio
        SELECT v_usuario, dia,TIME '07:00',TIME '21:00'
        FROM unnest(ARRAY['Lunes','Martes','Miercoles','Jueves','Viernes','Sabado','Domingo']) AS dias(dia);
    END LOOP;

    FOR v_i IN 1..4 LOOP
        INSERT INTO Actor_Usuario (contrasena_hash,tipo_actor) VALUES (v_hash,'Ente') RETURNING id_usuario INTO v_usuario;
        INSERT INTO Reportante DEFAULT VALUES RETURNING id_reportante INTO v_reportante;
        INSERT INTO Ente_Publico VALUES (v_usuario,'G-9900000' || v_i || '-0',v_entes[v_i],
            (ARRAY['Municipal','Estadal','Municipal','Nacional'])[v_i], 'Enlace de demostración ' || v_i,
            'DEMO-D-' || v_i, v_reportante);
    END LOOP;

    INSERT INTO Tutela
    SELECT e.id_usuario,h.cod_estado,h.cod_municipio,h.cod_parroquia,h.nombre_hito
    FROM Hito_Turistico h JOIN Estado s USING (cod_estado)
    JOIN Ente_Publico e ON e.rif_institucional = CASE
        WHEN s.nombre_estado ILIKE '%capital%' THEN 'G-99000001-0'
        WHEN s.nombre_estado ILIKE '%rida%' THEN 'G-99000002-0'
        WHEN s.nombre_estado ILIKE '%miranda%' THEN 'G-99000003-0'
        ELSE 'G-99000004-0'
    END;
END;
$$;

COMMIT;
