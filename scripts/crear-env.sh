#!/usr/bin/env bash
# Crea .env a partir de .env.example con una contraseña ALEATORIA, solo si .env no existe.
#
# Resuelve la contradicción del Reto 6: el repo no guarda ninguna contraseña, pero un
# Codespace recién creado (que no tiene .env) igual arranca sin que nadie escriba nada.
# Cada entorno nuevo recibe su propia credencial de desarrollo, que nunca sale de él.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f .env ]; then
  echo ".env ya existe: no se toca."
  exit 0
fi

# 24 bytes aleatorios en base64, sin símbolos. (Con `tr </dev/urandom | head` el tr muere
# por SIGPIPE y, con pipefail, el script se cortaba en silencio.)
clave=$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')
sed "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${clave}/" .env.example > .env
chmod 600 .env
echo ".env creado con una contraseña aleatoria de desarrollo."
