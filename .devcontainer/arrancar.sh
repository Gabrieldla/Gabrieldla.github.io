#!/usr/bin/env bash
# Se ejecuta en CADA arranque del Codespace (postStartCommand).
set -euo pipefail

# docker-in-docker levanta su propio dockerd; puede tardar unos segundos en aceptar conexiones.
for _ in $(seq 1 60); do
  docker info >/dev/null 2>&1 && break
  sleep 1
done

# --wait: no termina hasta que los tres servicios estén sanos (healthchecks del Reto 2).
# --build: el Codespace construye las imágenes desde este repositorio, así lo que corre
# es siempre el código de la rama, sin depender de credenciales del registro.
docker compose up -d --build --wait
