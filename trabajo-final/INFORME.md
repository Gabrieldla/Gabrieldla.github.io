# Informe técnico — Contribución a CloudNativePG

**Trabajo Final · IF-1116 Tópicos de Tecnologías de Información · 2026-II**

| | |
|---|---|
| **Equipo** | Rafael Sergio Alarcón Romero (202220909) · Gabriel De la Rivera (202220427) |
| **Proyecto** | [cloudnative-pg/cloudnative-pg](https://github.com/cloudnative-pg/cloudnative-pg) |
| **Issue** | [#11810](https://github.com/cloudnative-pg/cloudnative-pg/issues/11810) |
| **Pull Request** | [#11917](https://github.com/cloudnative-pg/cloudnative-pg/pull/11917) — abierto el 13/11/2026 |

---

## 1. El proyecto

### Qué hace

**CloudNativePG** es un *operador* de PostgreSQL para Kubernetes.

Un operador es un programa que corre **dentro** del clúster y administra algo que Kubernetes por sí solo no sabe manejar. Kubernetes sabe reiniciar un contenedor que se cae, pero no sabe que, en un grupo de bases de datos PostgreSQL, **solo una puede escribir** (el primario) y las demás solo leen (las réplicas). Si el primario muere, alguien tiene que elegir una réplica y promoverla. Eso no se arregla reiniciando un contenedor: hay que entender PostgreSQL.

CloudNativePG hace exactamente eso: crea el clúster de bases de datos, decide quién es el primario, promueve una réplica cuando hace falta, gestiona los backups y la replicación entre bases.

### Arquitectura general

El operador funciona con el patrón **bucle de reconciliación**, que es la idea central de Kubernetes:

```
  Estado deseado  ──┐
  (lo que pides     │
   en el YAML)      ├──►  El operador compara  ──►  Ejecuta lo que falta
                    │                               para que coincidan
  Estado real     ──┘
  (lo que hay
   en el clúster)
```

El usuario declara lo que quiere en un recurso de Kubernetes. El operador lo compara continuamente con lo que existe de verdad, y ejecuta lo necesario para que coincidan. Dos campos marcan ese ritmo:

- **`generation`** — sube cada vez que el usuario cambia el YAML
- **`observedGeneration`** — sube cuando el operador logró aplicar ese cambio

**Si `observedGeneration` se queda por detrás de `generation`, significa que el operador no pudo aplicar algo.** Esto es importante para entender el bug.

Dentro del operador hay varios *reconciliadores*, uno por tipo de recurso. El que nos interesa es el de `Subscription`, que administra las **suscripciones de replicación lógica** de PostgreSQL: el mecanismo por el que una base de datos copia continuamente los cambios de otra.

### Rol en el ecosistema cloud native

Las bases de datos fueron lo último en llegar a Kubernetes, y por un motivo concreto: **tienen estado**. Un servidor web sin estado se puede matar y recrear en otro nodo sin consecuencias; una base de datos no, porque sus datos están en disco y porque promover un primario equivocado puede partir el sistema en dos escrituras divergentes.

CloudNativePG es hoy el operador de PostgreSQL más usado, es parte de la **CNCF**, y su licencia es Apache-2.0.

Lo elegimos también porque es el terreno del curso: en el LAB-02 y el LAB-04 levantamos PostgreSQL sobre Kubernetes a mano, con sus `PersistentVolumeClaim`, sus `Secret` y sus sondas de salud. Este proyecto es la versión profesional de eso mismo.

### Evidencia de que el proyecto está activo

Verificado el 06/11/2026 contra la API de GitHub, no mirando la portada:

| Señal | Dato |
|---|---|
| Último push | **mismo día**, 00:44 |
| Commits recientes | de mantenedores y de bots de dependencias, a diario |
| Mantenedores respondiendo | `mnencia` comentó 4 veces el día anterior |
| Tamaño | **9.549 estrellas**, 812 forks |
| PRs mezclados | **20 de los últimos 20 cerrados** |

Esa última fila fue la que más pesó al elegir: dice que un PR de alguien de fuera se revisa, no se queda meses parado.

---

## 2. Onboarding: cómo se levanta el entorno

### Qué dice el `CONTRIBUTING.md`

El `CONTRIBUTING.md` del repositorio es corto y remite a dos sitios: las [guías de gobernanza del proyecto](https://github.com/cloudnative-pg/governance/blob/main/CONTRIBUTING.md) y, para contribuciones de código, a la carpeta [`contribute/`](https://github.com/cloudnative-pg/cloudnative-pg/tree/main/contribute).

De ahí sacamos dos requisitos que condicionaron todo el trabajo:

1. **DCO obligatorio** (*Developer Certificate of Origin*). Cada commit lleva una línea `Signed-off-by:`, que se añade con `git commit -s`. Es una declaración de que tienes derecho a aportar ese código. **Un bot bloquea el PR si falta.**
2. **Convenciones de nombres.** Las ramas se llaman `dev/<número de issue>` y los mensajes de commit siguen *Conventional Commits* (`fix:`, `feat:`, `docs:`…). Esto no está escrito en una guía: lo dedujimos mirando los últimos PRs y commits del proyecto.

### Herramientas usadas

| Herramienta | Para qué |
|---|---|
| **Git** | Control de versiones |
| **Go 1.26** | El lenguaje del proyecto |
| **Docker** (Rancher Desktop) | Correr las pruebas y el linter en Linux |
| **GitHub CLI (`gh`)** | Crear el fork, el PR y consultar la API |
| **golangci-lint v2.15.0** | El linter, en la versión exacta que usa su CI |

### Los pasos, del principio al final

**Paso 1 — El fork.** No se puede escribir directamente en el repositorio de otro. Lo que se hace es crear una copia propia (*fork*), trabajar ahí, y luego pedir que se integren los cambios (*pull request*).

Se hace desde la web: entrar al repositorio y pulsar el botón **Fork**. Queda en `github.com/Gabrieldla/cloudnative-pg`.

**Paso 2 — Clonar y conectar con el original.**

```bash
git clone https://github.com/Gabrieldla/cloudnative-pg.git
cd cloudnative-pg
git remote add upstream https://github.com/cloudnative-pg/cloudnative-pg.git
```

Ahora el repositorio local tiene **dos remotos**: `origin` es el fork (donde se escribe) y `upstream` es el original (de donde se traen las novedades). Sin `upstream`, el fork se queda atrás y los cambios dejan de aplicar.

**Paso 3 — La rama y la firma.**

```bash
git checkout -b dev/11810
git config user.name  "Gabriel De la Rivera"
git config user.email "202220427@urp.edu.pe"
```

**Paso 4 — Correr las pruebas, que es donde apareció la primera dificultad.**

Lo normal sería `go test ./...` y listo. En Windows no funciona:

```
internal\cmd\manager\instance\run\lease\stepdown.go:228:15: undefined: syscall.Kill
```

`syscall.Kill` es una llamada del sistema operativo que **solo existe en Unix**. El proyecto asume Linux, y aunque el archivo que nosotros tocamos no la usa, Go compila todo el paquete y sus dependencias antes de correr una sola prueba.

La solución fue correr las pruebas **dentro de un contenedor Linux**. Un contenedor es un Linux aislado que corre sobre tu máquina: no es una máquina virtual completa, comparte el núcleo del sistema, y arranca en segundos.

```bash
docker run --rm \
  -v "$PWD:/src" -w /src \
  -v cnpg-gomod:/go/pkg/mod \
  golang:1.27 \
  go test ./internal/management/controller/ -count=1
```

Lo que hace cada parte:

| | |
|---|---|
| `docker run` | Arranca un contenedor |
| `--rm` | Lo borra al terminar, para no acumular basura |
| `-v "$PWD:/src"` | **Monta** la carpeta actual dentro del contenedor, en `/src`. No copia: es la misma carpeta vista desde dentro |
| `-w /src` | Entra a esa carpeta antes de ejecutar |
| `-v cnpg-gomod:/go/pkg/mod` | Guarda las dependencias descargadas en un volumen, para no volver a bajarlas en cada ejecución |
| `golang:1.27` | La imagen: un Linux con Go ya instalado |
| `go test ...` | El comando que se ejecuta dentro |

El resultado aparece en tu terminal como si hubieras corrido Go localmente, pero se ejecutó en Linux.

**Paso 5 — El linter, con la versión exacta.**

```bash
docker run --rm -v "$PWD:/src" -w /src \
  golangci/golangci-lint:v2.15.0 \
  golangci-lint run ./internal/management/controller/...
```

El primer intento fue con otra versión y falló:

```
can't load config: the Go language version (go1.25) used to build golangci-lint
is lower than the targeted Go version (1.27.3)
```

Buscamos en su CI qué versión usan y encontramos que **la tienen fijada**:

```yaml
GOLANGCI_LINT_VERSION: "v2.15.0"
```

Correr la misma versión que su CI resolvió el problema. Es la misma lección de fijar versiones que aplicamos en el LAB-04, vista aquí en un proyecto real.

---

## 3. El issue

### Qué problema resolvía

[**#11810**](https://github.com/cloudnative-pg/cloudnative-pg/issues/11810) — *Subscription ALTER always re-sends failover, so any spec change fails on an enabled subscription*.

Una `Subscription` de replicación creada con el parámetro `failover: "true"` **quedaba permanentemente bloqueada**. Cualquier cambio posterior del YAML —aunque no tocara `failover`— hacía que el operador ejecutara:

```sql
ALTER SUBSCRIPTION "search_document_1" SET (binary = 'true', failover = 'true')
```

y PostgreSQL rechazaba **la sentencia entera**:

```
ERROR: cannot set option "failover" for enabled subscription (SQLSTATE 55000)
```

La razón está en PostgreSQL: `failover` —y `two_phase` desde la versión 18— solo se pueden cambiar con la suscripción **deshabilitada**.

El efecto es el que explicamos en la sección 1: `observedGeneration` nunca alcanzaba a `generation`, y **ningún cambio volvía a aplicarse jamás**. La única salida era borrar la suscripción y recrearla, lo que significa **volver a copiar todos los datos**.

### Por qué lo elegimos

1. **No es cosmético.** Deja un recurso inservible y la recuperación es cara.
2. **Hay que leer para resolverlo.** La issue describe el problema y propone **tres** caminos posibles, pero no da la solución. Elegir entre ellos fue nuestro aporte.
3. **Está acotado.** El archivo a tocar tiene 4.791 bytes y la función unas 30 líneas, y ya existía su archivo de pruebas.
4. **Conecta con el curso:** es SQL y es el bucle de reconciliación de un operador.
5. **Estaba libre de verdad.** Antes de elegirla descartamos **siete** candidatas que ya tenían PR abierto o estaban reclamadas en comentarios. Esta tenía cero PRs vinculados, cero comentarios y nadie asignado.

El 06/11 publicamos un comentario en la issue explicando nuestra lectura de la causa y preguntando cuál de los tres caminos preferían. **No hubo respuesta en una semana**, así que avanzamos con nuestro criterio y lo justificamos en el PR.

---

## 4. La contribución

### Dónde estaba el fallo

En `internal/management/controller/subscription_controller_sql.go`, la función `toSubscriptionAlterSQL` construía el `ALTER` así:

```go
toPostgresParameters(filterSubscriptionUpdatableParameters(obj.Spec.Parameters, pgMajorVersion))
```

Esa línea mete en la sentencia **todos** los parámetros que PostgreSQL permite actualizar. Nunca comprueba si han cambiado.

**La idea de fondo:** el operador reenviaba el estado deseado completo sin compararlo con el estado real. Reenviar algo que no cambió parece inofensivo, y aquí dejaba el recurso bloqueado para siempre.

### Qué hace el cambio

Tres piezas, +234 líneas y −12 en dos archivos.

**a) Leer la verdad del catálogo.** Antes de construir la sentencia, se consulta `pg_subscription` para saber el valor **real**:

```go
func getSubscriptionEnabledOnlyParameters(
    ctx context.Context, db *sql.DB, name string,
    pgMajorVersion int, requestedParameters map[string]string,
) (map[string]string, error)
```

Lee `subfailover` y, en PostgreSQL 18, también `subtwophasestate`. Ese segundo se consulta como `subtwophasestate <> 'd'`, porque guarda una letra: `'d'` deshabilitado, `'p'` pendiente, `'e'` habilitado — cualquier cosa distinta de `'d'` significa activado.

**b) Quitar del `SET` lo que no cambió.**

```go
func dropUnchangedEnabledOnlyParameters(parameters, currentParameters map[string]string) map[string]string
```

Si el valor pedido ya coincide con el real, el parámetro se omite. Y si no queda ninguno, **no se genera el `ALTER … SET` en absoluto**.

**c) Comparar booleanos como lo hace PostgreSQL.** Para PostgreSQL, `on` y `true` son lo mismo. Comparando los textos crudos, `on` frente a `true` parecería un cambio y volveríamos al bug. Usamos el helper que **el proyecto ya tenía**, `postgres.ParsePostgresConfigBoolean`, en lugar de escribir uno nuevo.

Un valor que no se puede interpretar se trata como diferente: la sentencia sale y PostgreSQL informa de qué está mal, en vez de que nuestro código lo trague en silencio.

### Decisiones tomadas y alternativas descartadas

La issue proponía tres caminos. Tomamos el tercero, acotado a los parámetros que de verdad fallan.

| Alternativa | Por qué se descartó |
|---|---|
| **Comparar todos los parámetros** contra el catálogo | Serían nueve columnas con condicionales por versión de PostgreSQL, para evitar reenviar opciones que PostgreSQL acepta sin protestar. Un cambio mucho mayor para un problema que no está rompiendo nada |
| **Envolver el cambio en `DISABLE` / `ENABLE`** | Arregla también el caso de cambiar `failover` de verdad, pero **corta la replicación** como efecto secundario de un cambio que puede ni tocar ese parámetro. Eso debería ser una decisión deliberada del usuario, no algo que el operador haga por su cuenta |

**Lo que el cambio NO arregla, y lo dijimos nosotros en el PR:** cambiar `failover` de verdad en una suscripción encendida sigue fallando, que es lo que PostgreSQL documenta. Ofrecimos hacerlo en un segundo PR si los mantenedores prefieren ese camino.

### Una optimización que salió de un error

El cambio solo consulta el catálogo **si el usuario pidió alguno de esos parámetros** y el servidor es PostgreSQL 17 o posterior. En cualquier otro caso, el número de idas y vueltas a la base de datos es el mismo que antes. El origen de esta optimización está en la sección 6.

### Las pruebas

Seis casos nuevos en `subscription_controller_sql_test.go`:

| Caso | Qué comprueba |
|---|---|
| `failover` coincide con el catálogo | Se quita del `SET`; `binary` sí se envía |
| Era el único parámetro | No se emite ningún `ALTER … SET` |
| El valor pedido **difiere** | Sí se envía |
| `on` frente a `true` | Se considera sin cambios |
| Valor del catálogo desconocido | El parámetro se mantiene |
| PostgreSQL 18 | `two_phase` también se quita |

**Cuatro de ellas fallan sin el arreglo. Dos pasan en ambos casos**, porque describen comportamiento que *no* debía cambiar. Eso demuestra que las pruebas no están escritas a medida de nuestra solución.

Resultado: **216 specs, todos en verde.** Linter sin avisos en los archivos tocados.

---

## 5. El proceso

### Estrategia de ramas

```
cloudnative-pg/cloudnative-pg  (upstream)
          │  fork
          ▼
Gabrieldla/cloudnative-pg  (origin)
          │
          └── dev/11810   ← la rama de trabajo
```

El nombre `dev/11810` no lo inventamos: miramos los PRs recientes del proyecto y la convención es `dev/<número de issue>`.

### Commits

Un solo commit, con mensaje en formato *Conventional Commits* y firmado con DCO:

```
fix(subscription): do not re-send unchanged failover and two_phase
...
Closes #11810
Signed-off-by: Gabriel De la Rivera <202220427@urp.edu.pe>
```

El cuerpo del mensaje explica el síntoma, la causa, la solución y lo que **no** arregla. `Closes #11810` hace que GitHub cierre la issue automáticamente cuando el PR se integre.

### El pull request

[**#11917**](https://github.com/cloudnative-pg/cloudnative-pg/pull/11917), abierto el 13/11/2026. La descripción sigue la misma estructura y termina preguntando a los mantenedores si prefieren el camino del `DISABLE`/`ENABLE`, para abrir conversación en vez de dar el tema por cerrado.

### Respuesta al code review

**Al momento de este informe no hay review humano todavía.** Lo que sí hubo fue respuesta automática del proyecto:

- Los checks de **DCO**, **issue vinculada** y **Snyk** (licencias y seguridad) pasaron.
- Un bot etiquetó el PR con `backport-requested`, `release-1.28` y `release-1.30`. Eso significa que, si se acepta, el arreglo se llevará también a las versiones ya publicadas — lo correcto para un *bug fix*, porque quien hoy tenga 1.28 en producción sufre este problema.
- Los workflows pesados (CI, CodeQL) quedaron en `action_required`: GitHub no los ejecuta automáticamente en el primer PR de un contribuidor desconocido, hasta que un mantenedor lo autoriza. No es un fallo del código.

---

## 6. Dificultades encontradas y cómo las resolvimos

### El proyecto no compila en Windows

Explicado en la sección 2. Se resolvió corriendo las pruebas en un contenedor Linux.

**Lo que aprendimos:** que un proyecto "no compile" no siempre significa que esté roto. Significa que asume un sistema operativo, y la forma correcta de trabajar con él es reproducir ese entorno, no pelearse con el propio.

### El linter fallaba por su propia versión

Explicado en la sección 2. Se resolvió usando la versión fijada en su CI.

### Rompimos una prueba que ya existía

Esta es la dificultad más interesante de las tres.

Nuestro arreglo añadía una consulta a `pg_subscription` dentro de `patchSubscription`. Eso hizo fallar una prueba **que no era nuestra** (`subscription object inherits error after patching`), porque su *mock* de base de datos no esperaba esa consulta:

```
there is a remaining expectation which was not matched: ExpectedExec =>
  expecting Exec or ExecContext which:
  - matches sql: 'ALTER SUBSCRIPTION "sub-one" SET PUBLICATION "pub-all"'
```

Había dos salidas:

1. **Modificar la prueba existente** para que esperara la consulta nueva. Funciona, pero toca un test que no es nuestro.
2. **Evitar la consulta cuando no hace falta.**

Elegimos la segunda, y no solo por no tocar su prueba: si una suscripción no usa `failover` ni `two_phase`, consultar el catálogo es **una ida y vuelta a la base de datos para no decidir nada**. El arreglo quedó más barato *y* dejó de romper nada.

**Lo que aprendimos:** un test que falla no siempre significa "arregla el test". A veces significa "tu diseño se puede mejorar".

### La firma DCO que casi se nos escapa

Habíamos configurado `git config format.signOff true` creyendo que firmaría los commits. No lo hace: esa opción solo afecta a `git format-patch`. El primer commit salió **sin firmar**, y el bot del proyecto lo habría rechazado.

Lo detectamos comprobando el mensaje antes de subirlo:

```bash
git log -1 --format=%B | grep -c "Signed-off-by"   # dio 0
git commit --amend --no-edit -s                     # lo arregla
```

**Lo que aprendimos:** configurar una herramienta no es lo mismo que comprobar que hace lo que uno cree. Es la misma lección que nos llevamos del LAB-04 con el `dependabot.yml` inválido.

### Cómo demostramos que el bug era real

No basta con que las pruebas propias pasen: eso solo demuestra que el código hace lo que uno quiso. Para demostrar que el **bug existía**, dejamos el arreglo entero puesto y revertimos **una sola línea** —la que filtra los parámetros— y volvimos a correr:

| | Código original | Con el arreglo |
|---|---|---|
| Resultado | ❌ **5 fallos** de 216 | ✅ **216 pasan** |

Aislar la línea responsable es más limpio que revertir el archivo entero, porque deja claro **exactamente** qué la causaba.

---

## 7. Estado del PR al momento de la entrega

| | |
|---|---|
| **Estado** | **Abierto** desde el 13/11/2026 |
| Cambios | +234 / −12 en 2 archivos |
| Checks automáticos | DCO ✅ · issue vinculada ✅ · Snyk licencias ✅ · Snyk seguridad ✅ |
| CI completo | A la espera de autorización de un mantenedor (normal en un primer PR) |
| Review humano | Todavía no |
| Etiquetas puestas por el proyecto | `backport-requested`, `release-1.28`, `release-1.30` |

Que el bot lo marque para backport a 1.28 y 1.30 indica que el proyecto trata este cambio como un arreglo que merece llegar a quienes ya lo sufren en producción.

---

## Uso de IA

Usamos asistencia de IA en el proceso, con la regla del curso: solo vale si podemos explicar cada línea.

**Dónde ayudó:** leer salidas largas deprisa (planes, logs de test, el grafo de dependencias), encontrar la convención de ramas y commits mirando el historial del proyecto, y localizar que el proyecto ya tenía un helper de booleanos en vez de escribir uno nuevo.

**Dónde no bastó:** las tres dificultades de la sección 6 —el fallo de compilación en Windows, la versión del linter y la prueba ajena rota— salieron de **ejecutar** las cosas, no de leerlas. Y la firma DCO ausente se detectó comprobando el resultado, no confiando en la configuración.
