# Perfil — Gabriel De la Rivera

Sitio personal publicado en https://gabrieldla.github.io y, desde el LAB-02, una aplicación de tres servicios en contenedores con un libro de visitas.

## Arquitectura

| Servicio | Qué hace | Imagen |
|---|---|---|
| `web` | nginx: sirve el perfil y hace de reverse proxy de `/api/` hacia la API | `ghcr.io/gabrieldla/perfil-web:1.0` |
| `api` | Libro de visitas en Python (Flask + gunicorn) | `ghcr.io/gabrieldla/perfil-api:1.0` |
| `db` | Postgres 16 con las tablas del libro de visitas y un volumen para los datos | se construye en local |

Dos redes: `web` solo ve a `api`, y solo `api` ve a `db`. **`web` es el único servicio que publica un puerto** hacia el host.

```
navegador ──8080──▶ web ──/api/──▶ api ──▶ db ──▶ volumen datos-db
                    └─ red frontend ─┘   └─ red backend ─┘
```

## Cómo arrancarlo en local

Necesitas Docker y Docker Compose (yo uso Rancher Desktop con el motor dockerd/moby).

```bash
bash scripts/crear-env.sh          # crea .env con una contraseña aleatoria (solo la primera vez)
docker compose up -d --build --wait
```

Cuando el comando termina, los tres servicios están sanos. Abre **http://localhost:8080**.

```bash
docker compose ps        # estado y salud de los tres servicios
docker compose logs -f   # logs
docker compose down      # apaga, conservando los mensajes
docker compose down -v   # apaga y BORRA el volumen: la base se reinicializa desde db/init/
```

## En GitHub Codespaces

`Code → Codespaces → Create codespace on main`. No hay que escribir ningún comando: el dev container genera el `.env`, levanta los tres servicios con `--wait` y abre la vista previa del puerto 8080 cuando todo está sano.

## Las imágenes

```bash
docker pull ghcr.io/gabrieldla/perfil-web:1.0
docker pull ghcr.io/gabrieldla/perfil-api:1.0
```

Tag fijo `1.0`, nunca `latest`. La de `db` no se publica porque solo agrega los scripts de `init/` sobre la imagen oficial de Postgres.

## Cómo se publica la página

Cada push a `main` despliega `index.html` con GitHub Pages. Ahí no hay backend: `libro-de-visitas.js` consulta `/api/mensajes` y, si no responde, deja la sección oculta y el resto del perfil se ve igual que siempre.

## Flujo de trabajo

- `main` protegida; todo cambio entra por pull request
- Una rama por cambio: `feature/*`, `fix/*`, `docs/*`, `reto/*`
- Mensajes de commit en imperativo, ≤ 50 caracteres

## Historial del curso

- **S02** — Sitio inicial, ramas y pull requests
- **S03** — Libro de visitas en tres contenedores, Compose, Codespaces y los seis retos

## Bitácora de decisiones (LAB-02)

### Reto 1: Imagen mínima

- **Decisión:** Dockerfile de la API en dos etapas. Empecé sobre `python:3.12.14-slim-trixie` y, tras medir en el Reto 5, la base final quedó en `python:3.12.14-alpine3.24` (99 MB y 0 CVE críticas/altas). La etapa `build` instala las dependencias en un venv (`/opt/venv`) y después le quita `pip`. La etapa final solo recibe el venv y `app.py`.
- **Alternativas que evalué:**
  - *`python:3.12-alpine`*: la base es mucho más chica, pero usa musl en vez de glibc. El riesgo conocido es que una librería no publique wheels para musl: entonces pip la compila y hay que meter `gcc` y headers, con builds lentos e imágenes más grandes. **Lo medí en vez de suponerlo:** para estas dependencias concretas (`flask`, `gunicorn`, `psycopg[binary]`) sí existen wheels musllinux y el build tarda 11 s sin ningún compilador. Por eso terminó siendo la base elegida en el Reto 5.
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
  perfil-api:multistage   206MB      ← multi-stage sobre slim-trixie (-87 %)
  perfil-api:alpine        99MB      ← base final, tras medir en el Reto 5 (-94 %)

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
  - La imagen base todavía trae su propio `pip` en `/usr/local`. Lo dejé para el Reto 5 y al final no hizo falta tocarlo: el escáner no reportó nada por `pip`, y el cambio de base resolvió el problema real.
  - Descarté Alpine por un motivo que resultó ser falso para este caso (que habría que compilar las dependencias). Al medirlo en el Reto 5 vi que no, y cambié la base. La lección es que "Alpine da problemas con Python" es un consejo general, no un hecho sobre mi aplicación: dependía de si mis tres dependencias publican wheels musllinux, y las publican.

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

### Reto 4: Red segmentada

- **Decisión:** dos redes definidas en el compose, `frontend` y `backend`. `web` está solo en `frontend`, `db` solo en `backend`, y `api` es el único conectado a las dos. Solo `web` publica un puerto (`8080:8080`); `api` y `db` no publican ninguno.
- **Alternativas que evalué:**
  - *Una sola red (lo que tenía antes)*: simple, pero todos se ven entre todos. Comprobado: antes de este cambio, `docker compose exec web getent hosts db` devolvía la IP de la base. Si alguien compromete nginx, que es lo único expuesto a Internet, llega directo a Postgres.
  - *Una red + `internal: true` para la base*: `internal` corta la salida a Internet del servicio, pero no impide que los contenedores de esa misma red se hablen. Resuelve otro problema (que la base no salga a la red), no el de este reto.
  - *Reglas de firewall dentro de los contenedores*: habría que instalar y mantener iptables en cada imagen, con privilegios extra (`NET_ADMIN`). Contradice el Reto 3 y las imágenes mínimas.
- **Por qué elegí esta:** es mínimo privilegio aplicado a la red y no depende de que ninguna imagen colabore. En Docker una red es un switch virtual: si `web` no está enchufado al mismo switch que `db`, no hay camino posible, y no depende del DNS ni de la configuración de nginx. La topología queda escrita en el compose, que es el mismo archivo que se revisa al calificar.
- **Fuentes consultadas:**
  - https://docs.docker.com/compose/how-tos/networking/
  - https://docs.docker.com/reference/compose-file/networks/
  - https://docs.docker.com/engine/network/drivers/bridge/
  - https://docs.docker.com/reference/compose-file/services/#ports (diferencia entre `ports` y `expose`)
- **Cómo lo verifiqué:**

  ```text
  # Criterio del enunciado
  $ docker compose exec web getent hosts db     → sin salida, código 2 (no resuelve)
  $ docker compose exec api getent hosts db     → 172.19.0.2   db  db
  $ docker compose exec web getent hosts api    → resuelve (nginx necesita llegar a la API)

  # Más fuerte que el DNS: tampoco hay ruta si uso la IP directa
  $ docker compose exec web nc -z -w 3 172.19.0.2 5432    → falla (sin ruta)
  $ docker compose exec api python -c "socket.create_connection(('172.19.0.2',5432),3)"  → conecta

  # Puertos publicados hacia el host
  $ docker compose ps
  api   3000/tcp                      ← solo EXPOSE, no publicado
  db    5432/tcp                      ← solo EXPOSE, no publicado
  web   0.0.0.0:8080->8080/tcp        ← el único camino de entrada
  $ curl localhost:3000 / localhost:5432 desde el host → cerrados
  ```

- **Qué no me funcionó / qué aprendí:**
  - Al principio pensé que bastaba con no publicar puertos. No alcanza: sin publicar nada, `web` igual llegaba a `db` por la red interna, que es justo el camino que usaría un atacante que ya está dentro de nginx. Publicar puertos protege del host hacia afuera; las redes protegen de un contenedor a otro.
  - La columna `PORTS` de `docker compose ps` muestra `3000/tcp` y `5432/tcp` aunque no estén publicados. Eso viene del `EXPOSE` del Dockerfile, que es solo documentación: lo que publica de verdad es `ports:` en el compose, y se distingue porque aparece con `0.0.0.0->`.

### Reto 5: Escaneo de vulnerabilidades

- **Decisión:** escaneo con Trivy las tres imágenes. El primer escaneo de `api` dio 44 vulnerabilidades altas, **todas sin parche disponible**, así que actualizar paquetes no servía de nada: venían de la base Debian. Cambié la base a Alpine y quité el binario `gosu` de la imagen de la base de datos. Las tres imágenes quedaron en 0 críticas y 0 altas.
- **Alternativas que evalué:**
  - *Actualizar los paquetes del sistema* (`apt-get upgrade` en el Dockerfile): era lo primero que pensé, pero las 44 vulnerabilidades tenían `FixedVersion` vacío, es decir que Debian todavía no publica corrección. Además hace la imagen no reproducible: el mismo Dockerfile da imágenes distintas según el día.
  - *Quedarme en Debian y aceptar los hallazgos*: defendible, porque casi todos los CVE eran de `util-linux`, `ncurses` y `perl-base`, paquetes que mi aplicación nunca ejecuta. Pero seguían en la imagen y cualquiera que la escanee los ve.
  - *Cambiar a `slim-bookworm`*: lo medí y fue peor: 60 hallazgos, 5 de ellos críticos, y 215 MB.
  - *Distroless*: menos superficie todavía, pero el Python de Debian 12 es 3.11 y rompe el venv, y sin shell no podría cumplir la verificación del Reto 3.
- **Por qué elegí esta:** el problema no era una vulnerabilidad puntual sino **cuántos paquetes arrastra la base**. Alpine trae BusyBox en vez de `util-linux`, `perl` y `systemd`, así que esos CVE no existen porque el software directamente no está. Es la diferencia entre parchear y no instalar. Y de paso la imagen bajó de 206 MB a 99 MB.
- **Fuentes consultadas:**
  - https://trivy.dev/latest/docs/target/container_image/
  - https://avd.aquasec.com/nvd/cve-2026-76642
  - https://www.first.org/cvss/ (cómo se lee la severidad)
  - https://github.com/tianon/gosu (para qué sirve y cuándo hace falta)
- **Una vulnerabilidad concreta:** `CVE-2026-76642`, severidad HIGH, en el paquete `util-linux` (versión `1:2.41.5-0+deb13u1`), presente en la imagen porque es parte de la base Debian, no porque yo la instale. util-linux no verifica el código de salida del *mount helper* antes de correr los hooks de post-montaje, y un usuario sin privilegios puede aprovechar `X-mount.idmap` o `X-mount.owner` para terminar escalando privilegios. Estado en Debian: `affected`, **sin parche publicado**. No la resolví parcheando, porque no había parche: la eliminé cambiando a una base que no incluye `util-linux`. Aun con parche, el riesgo real en mi contenedor era bajo, porque la API no monta sistemas de archivos y corre como usuario sin privilegios; pero eso reduce el impacto, no la presencia del paquete.
- **Cómo lo verifiqué:**

  ```text
  ANTES                                          DESPUÉS
  api  (slim-trixie)  44 HIGH, 0 CRITICAL        api  (alpine3.24)   0 HIGH, 0 CRITICAL
  web  (nginx-unprivileged alpine)  0 / 0        web                 0 / 0  (sin cambios)
  db   (postgres alpine)  21 HIGH, 1 CRITICAL    db   (sin gosu)     0 HIGH, 0 CRITICAL

  # Comparación de bases que hice antes de decidir:
  base                    tamaño   CRITICAL+HIGH
  python:3.12.14-slim-trixie   206 MB      44
  python:3.12.14-slim-bookworm 215 MB      60   ← peor
  python:3.12.14-alpine3.24     99 MB       0   ← elegida

  $ docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.74.0 \
      image --scanners vuln --severity CRITICAL,HIGH perfil-api:latest
  (sin hallazgos)

  # Y después del cambio, los criterios de los retos anteriores siguen pasando:
  compose ps → los tres healthy | whoami → nginx/app/postgres | web no resuelve db
  ```

- **Qué no me funcionó / qué aprendí:**
  - Las 22 vulnerabilidades de `db` no estaban en Postgres sino en **`gosu`**, un binario de Go que la imagen oficial usa para bajar de root a `postgres`. Trivy las reporta contra `stdlib`, la biblioteca estándar de Go con la que fue compilado. Como desde el Reto 3 el contenedor ya arranca como `postgres`, ese binario nunca se ejecuta, así que lo borré. La contrapartida, y hay que decirla: esa imagen ya no se puede correr como root.
  - Creía que "cero vulnerabilidades" era la meta. No lo es: el resultado de hoy es 0 con la base de datos de Trivy de hoy, y mañana aparece un CVE nuevo en la misma imagen sin que yo toque nada. Lo que vale es el proceso (escanear, entender el origen, decidir) y la fecha del escaneo.
  - La primera vez escaneé con `--severity CRITICAL,HIGH` y la tabla era tan larga que no se entendía nada. Sacando el JSON y contando por paquete se vio enseguida que 4 de cada 5 hallazgos eran del mismo grupo de paquetes del sistema, y ahí quedó claro que el problema era la base y no una dependencia mía.

### Reto 6: Cero secretos… y aun así arranca solo

- **Decisión:** el repositorio no contiene ninguna contraseña. `compose.yaml` toma las credenciales de un `.env` que está en `.gitignore`, y lo que sí se commitea es `.env.example`, con `POSTGRES_PASSWORD=` **vacío**. La contradicción con el B3 la resuelve `scripts/crear-env.sh`, que el devcontainer ejecuta en `postCreateCommand`: si no existe `.env`, lo genera con una contraseña aleatoria de 32 caracteres. Cada entorno nuevo (mi laptop, un Codespace mío, el Codespace del profesor) se fabrica su propia credencial y nunca sale de ahí.
- **Alternativas que evalué:**
  - *Secretos de Codespaces* (Settings → Codespaces → Secrets): es el mecanismo oficial y parecía la respuesta obvia, pero **están atados a mi cuenta**. Cuando el profesor cree un Codespace en mi repositorio para calificar, esos secretos no existen, `POSTGRES_PASSWORD` llega vacío y no arranca nada. Sirven para mis credenciales reales, no para que otro pueda levantar el proyecto.
  - *Una contraseña de desarrollo escrita en `.env.example` o como valor por defecto en el compose* (`${POSTGRES_PASSWORD:-postgres}`): arranca en cualquier lado sin hacer nada, y es lo que hace mucha gente. Pero es exactamente lo que el enunciado descuenta con −5: una credencial en el repositorio. Y el hábito es el problema, porque el día que ese compose se copie a algo que sí mira Internet, la contraseña ya viene puesta.
  - *Secretos de Compose* (`secrets:` + `POSTGRES_PASSWORD_FILE`): es lo correcto para producción, porque el valor llega por un archivo montado y no por una variable de entorno, que se ve en `docker inspect` y en `/proc/<pid>/environ`. Postgres lo soporta, pero la API del curso solo lee `DB_PASSWORD` como variable y no tiene versión `_FILE`, así que habría quedado a medias: la base con secreto de archivo y la API con variable. Preferí una sola forma coherente y explicarla.
- **Por qué elegí esta:** cumple las dos condiciones a la vez, que es lo que el reto pide. Un Codespace recién creado arranca sin que nadie escriba nada, y aun así no hay ninguna contraseña en el repositorio ni en las capas de las imágenes. La credencial es de desarrollo y desechable: dura lo que dure ese entorno, y como la base de datos no publica puertos (Reto 4), solo es alcanzable desde la red interna de esa aplicación. Un secreto de producción se maneja distinto: gestor de secretos, rotación y auditoría, y en el LAB-03 esto se convierte en un `Secret` de Kubernetes.
- **Fuentes consultadas:**
  - https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/
  - https://docs.docker.com/compose/how-tos/use-secrets/
  - https://docs.github.com/es/codespaces/managing-your-codespaces/managing-your-account-specific-secrets-for-github-codespaces
  - https://containers.dev/implementors/json_reference/ (`postCreateCommand` vs `postStartCommand`)
- **Cómo lo verifiqué:**

  ```text
  $ git log --all --full-history -- .env
  (sin salida: nunca estuvo en el historial)

  $ git check-ignore -v .env
  .gitignore:3:.env    .env

  $ docker history --no-trunc perfil-api:latest | grep "<la contraseña>"    → 0 coincidencias
    (igual en perfil-web y perfil-db)

  $ docker inspect -f '{{json .Config.Env}}' perfil-api:latest
  ["PATH=...","LANG=C.UTF-8","PYTHON_VERSION=3.12.14",...]   ← ninguna credencial

  $ cat .env.example
  POSTGRES_PASSWORD=          ← vacío, y el compose falla con un mensaje claro si no se define
  ```

- **Qué no me funcionó / qué aprendí:**
  - `scripts/crear-env.sh` terminaba en silencio sin crear el archivo. La causa era `set -o pipefail` junto con `tr -dc ... < /dev/urandom | head -c 32`: cuando `head` corta la lectura, `tr` muere por SIGPIPE, el pipeline devuelve 141 y `set -e` aborta el script sin mensaje. Lo cambié por `head -c 24 /dev/urandom | base64`, donde ningún proceso queda escribiendo en una tubería cerrada.
  - La contraseña **sí** es visible con `docker inspect` del **contenedor** y en `/proc/<pid>/environ` dentro de él. Eso no lo arregla este diseño y no hay que fingir que sí: lo que se evita es que viaje en el repositorio y en las imágenes. Para que tampoco esté en el entorno del proceso hace falta el enfoque de `secrets:` con archivos.
  - El script tiene que ser idempotente. Si pisara un `.env` existente, cambiaría la contraseña mientras el volumen de Postgres conserva la vieja, y la API dejaría de autenticarse. Por eso, si `.env` existe, no lo toca.
