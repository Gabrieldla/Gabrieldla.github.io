#!/usr/bin/env bash
# Se ejecuta en CADA arranque del Codespace (postStartCommand).
set -euo pipefail

# docker-in-docker levanta su propio dockerd; puede tardar unos segundos en aceptar conexiones.
for _ in $(seq 1 60); do
  docker info >/dev/null 2>&1 && break
  sleep 1
done

# --wait: no termina hasta que los tres servicios estén sanos (healthchecks del Reto 2).
docker compose up -d --wait
