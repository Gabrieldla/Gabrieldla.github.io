# Postgres con el esquema del libro de visitas ya incluido.
#
# La imagen oficial ejecuta, en orden alfabético, todo .sql que encuentre en
# /docker-entrypoint-initdb.d/, pero SOLO si el directorio de datos está vacío,
# es decir, la primera vez que arranca con un volumen nuevo.
FROM postgres:16-alpine

COPY init/ /docker-entrypoint-initdb.d/

# La imagen oficial arranca como root y baja a postgres con gosu. Declarando USER acá,
# el contenedor nunca es root: el volumen ya pertenece a postgres (uid 70), así que
# el proceso puede escribir sus datos igual.
USER postgres
