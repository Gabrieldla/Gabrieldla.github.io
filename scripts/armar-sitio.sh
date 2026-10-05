#!/usr/bin/env bash
# Arma la carpeta _site/ con SOLO lo que debe publicarse en GitHub Pages.
#
# El mismo script lo usan el job build (que sube el artefacto) y el job test (que
# corre Vitest sobre esa carpeta). Así se prueba exactamente lo que se publica.
set -euo pipefail
cd "$(dirname "$0")/.."

rm -rf _site
mkdir -p _site
cp index.html libro-de-visitas.js estilos.css _site/
# Las imágenes, si algún día hay.
if [ -d img ]; then cp -r img _site/; fi

echo "_site/ armado con:"
ls -1 _site
