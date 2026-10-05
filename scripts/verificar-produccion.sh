#!/usr/bin/env bash
# Comprueba el sitio YA PUBLICADO. Que deploy-prod termine en verde solo significa que
# GitHub aceptó el artefacto, no que la página funcione: esto entra por la URL real.
#
# Uso: bash scripts/verificar-produccion.sh https://gabrieldla.github.io
set -uo pipefail

URL=${1:-https://gabrieldla.github.io}
URL=${URL%/}
fallos=0

# Pages tarda unos segundos en servir la versión nueva: se reintenta antes de rendirse.
echo "Esperando a que $URL responda..."
pagina=""
for intento in $(seq 1 12); do
  pagina=$(curl -fsS --max-time 10 "$URL/" 2>/dev/null) && break
  echo "  intento $intento sin respuesta todavía, reintento en 10 s"
  sleep 10
done

if [ -z "$pagina" ]; then
  echo "FALLA: el sitio no respondió después de 12 intentos."
  exit 1
fi

codigo=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$URL/")
if [ "$codigo" = "200" ]; then
  echo "  ok    la página responde 200"
else
  echo "  FALLA la página responde $codigo"
  fallos=$((fallos + 1))
fi

if printf '%s' "$pagina" | grep -q "Gabriel De la Rivera"; then
  echo "  ok    aparece mi nombre"
else
  echo "  FALLA no aparece mi nombre: se publicó algo que no es mi perfil"
  fallos=$((fallos + 1))
fi

# En Pages no hay backend. El libro de visitas tiene que quedarse oculto, no romper
# la página: si alguien quita el atributo hidden, en producción se vería una sección
# vacía con un formulario que no funciona.
if printf '%s' "$pagina" | grep -q 'id="libro-de-visitas" hidden'; then
  echo "  ok    el libro de visitas arranca oculto (en Pages no hay /api)"
else
  echo "  FALLA el libro de visitas no arranca oculto: en Pages se vería roto"
  fallos=$((fallos + 1))
fi

# Lo que NO debe estar publicado.
for interno in compose.yaml .env.example api/app.py; do
  c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$URL/$interno")
  if [ "$c" = "404" ]; then
    echo "  ok    /$interno no está publicado (404)"
  else
    echo "  FALLA /$interno responde $c: no debería publicarse"
    fallos=$((fallos + 1))
  fi
done

echo
if [ "$fallos" -eq 0 ]; then
  echo "Producción verificada: el despliegue quedó bien."
else
  echo "Producción con $fallos problemas. Hay que volver atrás."
  exit 1
fi
