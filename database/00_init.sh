#!/bin/sh
set -e

# Ejecuta en orden estricto todos los scripts .sql dentro de las subcarpetas de database/.
# La imagen oficial postgres:16.4-alpine solo procesa archivos en la raiz de /docker-entrypoint-initdb.d/,
# por lo que este script recorre 01_ddl -> 02_security -> 03_logic -> 04_seeds en orden alfabetico.

for folder in 01_ddl 02_security 03_logic 04_seeds; do
    dir="/database_scripts/${folder}"
    if [ ! -d "${dir}" ]; then
        echo "[RutasVenezuela-Init] Carpeta omitida (no existe): ${dir}"
        continue
    fi

    has_sql=0
    for sql_file in "${dir}"/*.sql; do
        if [ -f "${sql_file}" ]; then
            if [ "${has_sql}" -eq 0 ]; then
                echo "[RutasVenezuela-Init] Ejecutando carpeta: ${folder}"
                has_sql=1
            fi
            echo "[RutasVenezuela-Init]   -> ${sql_file}"
            psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" -f "${sql_file}"
        fi
    done

    if [ "${has_sql}" -eq 0 ]; then
        echo "[RutasVenezuela-Init] Sin archivos .sql en ${folder}, continuando..."
    fi
done
