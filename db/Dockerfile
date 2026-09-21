# Postgres con el esquema del libro de visitas ya incluido.
#
# La imagen oficial ejecuta, en orden alfabético, todo .sql que encuentre en
# /docker-entrypoint-initdb.d/, pero SOLO si el directorio de datos está vacío,
# es decir, la primera vez que arranca con un volumen nuevo.
FROM postgres:16.15-alpine3.24

COPY init/ /docker-entrypoint-initdb.d/

# La imagen oficial arranca como root y baja a postgres con gosu. Declarando USER acá,
# el contenedor nunca es root: el volumen ya pertenece a postgres (uid 70), así que
# el proceso puede escribir sus datos igual.
# gosu solo lo usa el entrypoint cuando arranca como root para bajar a postgres.
# Como este contenedor ya arranca directamente como postgres, nunca se ejecuta, y su
# binario arrastra 22 CVE (1 crítica) de la versión de Go con que fue compilado (Reto 5).
# Contrapartida: esta imagen ya no puede correrse como root.
RUN rm -f /usr/local/bin/gosu

USER postgres
