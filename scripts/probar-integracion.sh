#!/usr/bin/env bash
# Pruebas de integración del contrato de la API, pasando SIEMPRE por nginx.
#
# Vitest prueba el sitio estático y pytest la validación de la API por separado. Esto
# prueba la aplicación entera: los tres contenedores levantados, y las peticiones
# entrando por el puerto 8080 como lo haría un navegador. Si algo de la cadena está
# mal conectado (el proxy, la red, las credenciales), aquí se nota.
set -uo pipefail
cd "$(dirname "$0")/.."

BASE=${BASE:-http://localhost:8080}
fallos=0

# Devuelve "<cuerpo>\n<código>" en una sola llamada. Sin -o, que en Git Bash no puede
# escribir en /dev/null y hace que curl termine con error aunque la petición funcione.
pedir() {
  curl -s -w '\n%{http_code}' "$@"
}

codigo_de() { printf '%s' "$1" | tail -n 1; }

comprobar() {  # comprobar <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then
    echo "  ok    $1 ($3)"
  else
    echo "  FALLA $1: esperaba $2, obtuve $3"
    fallos=$((fallos + 1))
  fi
}

echo "== GET /api/health"
comprobar "responde 200" 200 "$(codigo_de "$(pedir "$BASE/api/health")")"

echo "== POST /api/mensajes"
unico="integracion-$(date +%s)"
r=$(pedir -X POST "$BASE/api/mensajes" -H 'Content-Type: application/json' \
      -d "{\"nombre\":\"Integracion\",\"mensaje\":\"$unico\"}")
comprobar "un mensaje válido devuelve 201" 201 "$(codigo_de "$r")"

r=$(pedir -X POST "$BASE/api/mensajes" -H 'Content-Type: application/json' \
      -d '{"mensaje":"sin nombre"}')
comprobar "sin nombre devuelve 400" 400 "$(codigo_de "$r")"

largo=$(printf 'a%.0s' $(seq 1 281))
r=$(pedir -X POST "$BASE/api/mensajes" -H 'Content-Type: application/json' \
      -d "{\"nombre\":\"Largo\",\"mensaje\":\"$largo\"}")
comprobar "con más de 280 caracteres devuelve 400" 400 "$(codigo_de "$r")"

echo "== GET /api/mensajes"
lista=$(pedir "$BASE/api/mensajes")
comprobar "responde 200" 200 "$(codigo_de "$lista")"

# Que el mensaje creado se pueda leer demuestra que llegó hasta Postgres y volvió,
# no que la API lo guardó en memoria.
if printf '%s' "$lista" | grep -q "$unico"; then
  echo "  ok    el mensaje recién creado aparece en la lista"
else
  echo "  FALLA el mensaje recién creado NO aparece en la lista"
  fallos=$((fallos + 1))
fi

echo
if [ "$fallos" -eq 0 ]; then
  echo "Contrato de la API: las 6 comprobaciones pasaron."
else
  echo "Contrato de la API: $fallos comprobaciones fallaron."
  exit 1
fi
