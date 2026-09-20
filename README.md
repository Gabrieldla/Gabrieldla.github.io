# Perfil — Gabriel De la Rivera

Sitio personal publicado en https://gabrieldla.github.io

## Cómo se publica
Cada push a `main` despliega automáticamente con GitHub Pages.

## Flujo de trabajo
- `main` protegida; todo cambio entra por pull request
- Una rama por cambio: `feature/*`, `fix/*`
- Mensajes de commit en imperativo, ≤ 50 caracteres

## Historial del curso
- **S02** — Sitio inicial, ramas y pull requests

## Bitácora de decisiones (LAB-02)

### Reto 1: Imagen mínima

- **Decisión:** Dockerfile de la API en dos etapas sobre `python:3.12.14-slim-trixie`. La etapa `build` instala las dependencias en un venv (`/opt/venv`) y después le quita `pip`. La etapa final solo recibe el venv y `app.py`.
- **Alternativas que evalué:**
  - *`python:3.12-alpine`*: la base es más chica (~50 MB), pero usa musl en vez de glibc. Muchas librerías de Python no publican wheels para musl, y entonces pip las compila, lo que obliga a meter `gcc` y headers y termina dando builds lentos e imágenes más grandes. musl además cambia la resolución DNS y la asignación de memoria respecto de glibc.
  - *Distroless (`gcr.io/distroless/python3-debian12`)*: no tiene shell ni gestor de paquetes, así que la superficie de ataque es mínima. Pero trae Python 3.11 (el de Debian 12) y el venv está construido con 3.12, así que no son compatibles. Y sin shell ni `whoami`, el comando de verificación del Reto 3 (`docker compose exec api whoami`) ni siquiera podría correr.
  - *Una sola etapa `slim` con `--no-cache-dir`*: pesaría casi lo mismo (~220 MB), pero `pip` y los archivos de instalación quedarían en la imagen final. El criterio pide dos etapas y que no haya herramientas de build.
- **Por qué elegí esta:** `slim` usa glibc, así que `psycopg[binary]` y `gunicorn` se instalan como wheels precompiladas y no hace falta ningún compilador. Las dos etapas usan la misma base, así que el venv apunta al mismo `/usr/local/bin/python` en las dos. Y conserva `sh`, que hace falta para `exec` y para el healthcheck.
- **Fuentes consultadas:**
  - https://docs.docker.com/build/building/multi-stage/
  - https://pythonspeed.com/articles/alpine-docker-python/
  - https://github.com/GoogleContainerTools/distroless
  - https://hub.docker.com/_/python
  - https://github.com/wagoodman/dive
- **Cómo lo verifiqué:**

  ```text
  $ docker images perfil-api
  REPOSITORY:TAG          SIZE
  perfil-api:ingenua      1.65GB     ← FROM python:3.12.14-trixie, una etapa
  perfil-api:multistage   206MB      ← este Dockerfile (-87 %)

  $ docker history perfil-api:multistage      (capas propias arriba, base abajo)
  CMD ["gunicorn" "-b" "0.0.0.0:3000" "app:app"]   0B
  EXPOSE [3000/tcp]                                0B
  COPY app.py .                                    12.3kB
  COPY /opt/venv /opt/venv                         34.9MB   ← lo único que viene de la etapa build
  WORKDIR /app                                     8.19kB
  ENV PATH=/opt/venv/bin:...                       0B
  ...capas de python:3.12.14-slim-trixie...        ~134MB

  $ docker run --rm --entrypoint sh perfil-api:multistage -c 'ls /usr/bin/gcc*; ls /root/.cache; ls /opt/venv/lib/python3.12/site-packages/pip'
  (nada: sin compiladores, sin caché de pip, venv sin pip)

  $ dive --ci perfil-api:multistage
  efficiency: 97.18 %   wastedBytes: 5.6 MB  (todo en /var/cache/debconf, heredado de la base)
  ```

- **Qué no me funcionó:**
  - La primera versión multi-stage pesaba 223 MB y todavía traía `pip` dentro de `/opt/venv`, porque `python -m venv` lo instala por defecto. Me di cuenta al revisar la imagen por dentro, no mirando el tamaño. Lo resolví desinstalándolo en la etapa `build`: 223 → 206 MB.
  - Esperaba que `dive` le diera mejor "eficiencia" a la imagen chica, y fue al revés: 99.3 % la ingenua contra 97.2 % la multi-stage. Aprendí que esa métrica mide archivos duplicados entre capas, no el tamaño total, así que no sirve para comparar el antes y el después de este reto.
  - La imagen base todavía trae su propio `pip` en `/usr/local`. Lo dejé para el Reto 5, para medir con el escáner si quitarlo cambia algo.
