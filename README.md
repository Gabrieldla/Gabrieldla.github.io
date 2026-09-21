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

### Reto 2: Arranque ordenado

- **Decisión:** los tres servicios tienen healthcheck. `db` usa `pg_isready`, `api` consulta su propio `/api/health` con `urllib` de Python y `web` pide `/healthz` a nginx con `curl`. Las dependencias usan `condition: service_healthy`, así que el orden queda db → api → web, y cada uno espera a que el anterior esté **sano**, no solo encendido.
- **Alternativas que evalué:**
  - *`depends_on` simple (lista)*: solo ordena el arranque de los contenedores, no espera a que Postgres acepte conexiones. La API arrancaba igual, pero quedaba unos segundos respondiendo 503 y `--wait` no tenía nada que esperar.
  - *Un script de espera en la API* (`wait-for-it.sh` o un bucle en el entrypoint): mete lógica de infraestructura en la imagen y exige un shell y herramientas extra. Además, solo cubre el arranque, no una caída posterior de la base.
  - *Healthcheck de la API con `curl` o `wget`*: la imagen slim no los tiene, e instalarlos solo para esto agrega peso y paquetes vulnerables (Reto 5). Python ya está en la imagen, y `urllib` es parte de la librería estándar.
- **Por qué elegí esta:** el estado "sano" lo declara cada servicio con un chequeo real, y Compose lo usa para ordenar. `/api/health` de la API solo responde 200 si **alcanza la base**, así que "api sana" significa "api que puede atender", no "proceso vivo". El `HEALTHCHECK` de `api` y `web` va en el **Dockerfile** porque es parte de la imagen: viaja con ella a GHCR y sirve aunque alguien la corra sin este compose. El de `db` va en **compose.yaml** porque usa la imagen oficial de Postgres y depende de `POSTGRES_USER`/`POSTGRES_DB`, que se definen en el compose. En `web` agregué un `location = /healthz` que responde nginx mismo, sin pasar por disco ni por la API y sin llenar el access log cada 10 s.
- **Fuentes consultadas:**
  - https://docs.docker.com/reference/dockerfile/#healthcheck
  - https://docs.docker.com/reference/compose-file/services/#healthcheck
  - https://docs.docker.com/compose/how-tos/startup-order/
  - https://www.postgresql.org/docs/16/app-pg-isready.html
  - https://docs.python.org/3/library/urllib.request.html
- **Cómo lo verifiqué:**

  ```text
  $ docker compose up -d --build --wait        # vuelve al prompt solo cuando todo está sano (~18 s)
   Container perfil-db-1   Healthy
   Container perfil-api-1  Healthy
   Container perfil-web-1  Healthy

  $ docker compose ps
  SERVICE   STATUS                    PORTS
  api       Up 11 seconds (healthy)   3000/tcp
  db        Up 17 seconds (healthy)   5432/tcp
  web       Up 5 seconds (healthy)    0.0.0.0:8080->8080/tcp

  # Prueba extra: ¿el healthcheck detecta una caída real?
  $ docker compose stop db && sleep 35 && docker compose ps -a
  api       Up 46 seconds (unhealthy)      ← /api/health responde 503
  db        Exited (0) 35 seconds ago
  $ docker compose up -d --wait            ← db vuelve, api se recupera sola sin reiniciarse
  ```

- **Qué no me funcionó / qué aprendí:**
  - En el healthcheck de `db` escribí primero `$POSTGRES_USER` con un solo `$`. Compose lo reemplaza **en el host** al leer el archivo, no dentro del contenedor. Con `$$` la variable llega literal y la expande el shell del contenedor.
  - Esperaba que Docker reiniciara la API cuando quedó `unhealthy`, y no lo hace: Docker solo **marca** el estado, y `depends_on` lo usa únicamente en el arranque. Reiniciar según la salud es trabajo de un orquestador; en Kubernetes eso es la `livenessProbe` (LAB-03).
  - Al escribir los `HEALTHCHECK` con un script se me perdió la `\` de continuación de línea. Docker lo aceptó igual en una sola línea, pero lo corregí para que se pueda leer.

### Reto 3: Nadie es root

- **Decisión:** los tres contenedores corren con un usuario sin privilegios. `web` usa la imagen `nginxinc/nginx-unprivileged` (usuario `nginx`, uid 101, escucha en 8080); `api` crea un usuario `app` (uid 10001) con `useradd --system` y lo declara con `USER app`; `db` declara `USER postgres` (uid 70) sobre la imagen oficial.
- **Alternativas que evalué:**
  - *`nginx` oficial + `user: "101"` en compose*: la imagen oficial arranca como root **a propósito**, por dos motivos. Uno, escucha en el puerto 80, y en Linux los puertos menores a 1024 son privilegiados: solo puede abrirlos root o un proceso con la capacidad `CAP_NET_BIND_SERVICE`. Dos, su entrypoint escribe el pid en `/var/run/nginx.pid` y usa `/var/cache/nginx`, directorios que pertenecen a root. Forzando el usuario hay que además reescribir la config y arreglar permisos a mano.
  - *Dar `CAP_NET_BIND_SERVICE` o bajar `net.ipv4.ip_unprivileged_port_start`*: permite seguir en el 80 sin ser root, pero agrega una capacidad o un sysctl al contenedor. No hace falta: quien decide el puerto público es `ports:` del compose, y dentro puede ser cualquiera.
  - *Dejar `db` como viene*: la imagen oficial de Postgres arranca su entrypoint como **root** y recién después baja a `postgres` con `gosu`. O sea, el servidor ya corría como `postgres`, pero `docker compose exec db whoami` devolvía `root`, porque `exec` usa el usuario declarado en la imagen. Con `USER postgres` ya no hay ningún momento en que algo corra como root.
- **Por qué elegí esta:** `nginx-unprivileged` es la imagen que mantiene el propio proyecto nginx justamente para este caso: ya viene con los directorios y la config preparados para el usuario `nginx` y escuchando en 8080, así que no hay que parchear nada. En `api`, un uid alto y fijo (10001) evita chocar con usuarios del sistema. Los archivos de la aplicación siguen siendo de root y el usuario solo puede leerlos: el proceso no puede modificar su propio código.
- **Fuentes consultadas:**
  - https://github.com/nginxinc/docker-nginx-unprivileged
  - https://docs.docker.com/reference/dockerfile/#user
  - https://github.com/docker-library/postgres (uso de gosu en el entrypoint)
  - https://man7.org/linux/man-pages/man7/capabilities.7.html (CAP_NET_BIND_SERVICE)
- **Cómo lo verifiqué:**

  ```text
  $ for s in web api db; do docker compose exec $s whoami; done
  nginx
  app
  postgres

  # Y el proceso PID 1 de cada contenedor, no solo la shell del exec:
  web  → Name: nginx      Uid: 101
  api  → Name: gunicorn   Uid: 10001
  db   → Name: postgres   Uid: 70

  # Con el volumen vacío, Postgres se inicializa igual sin pasar por root:
  $ docker compose down -v && docker compose up -d --wait
  db-1 | database system is ready to accept connections
  db-1 | CREATE DATABASE
  → la API devuelve los 2 mensajes de ejemplo que cargan los scripts de init/
  ```

- **Qué no me funcionó / qué aprendí:**
  - Mi duda era si `USER postgres` rompería la inicialización, porque el entrypoint oficial hace `chown` del directorio de datos y eso normalmente exige root. No pasa: el volumen nombrado hereda el dueño del directorio dentro de la imagen (`postgres`, uid 70), así que el proceso puede escribir. Lo probé a propósito con `down -v` para partir de un volumen vacío, que es el caso que falla si algo está mal.
  - La imagen de la API no trae `ps`, así que para ver el usuario real del proceso tuve que leer `/proc/1/status` en vez de usar `ps`. Otra consecuencia de que sea una imagen mínima.
