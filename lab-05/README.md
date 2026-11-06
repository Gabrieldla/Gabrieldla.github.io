# LAB-05: Terraform en Google Cloud

> ✅ **Los tres labs completados**, los tres al 100 %. Evidencia y bitácora abajo.

## Evidencia

| Lab | Puntaje | Captura | Carpeta |
|-----|---------|---------|---------|
| **GSP233 — Deploy Kubernetes Load Balancer Service with Terraform** | **100 / 100** | [nginx](evidencia/gsp233-nginx.jpg) · [progreso](evidencia/gsp233-progreso.jpg) | [`01-gsp233/`](01-gsp233/) |
| **GSP497 — Cloud Operations for GKE** | **100 / 100** | [score](evidencia/gsp497-score.jpg) · [progreso](evidencia/gsp497-progreso.jpg) · [monitoring](evidencia/gsp497-monitoring.jpg) | [`02-gsp497/`](02-gsp497/) |
| **GSP345 — Challenge Lab** | **100 / 100** | [score](evidencia/gsp345-score.jpg) | [`03-gsp345/`](03-gsp345/) |

**Perfil público de Google Skills:** _(pendiente)_

### Challenge Lab, tarea por tarea

| Tarea | Qué hace | Plan | Resultado |
|-------|----------|------|-----------|
| 2 | Importar `tf-instance-1` y `tf-instance-2` | `plan-2.txt` | `0 add, 2 change, 0 destroy` |
| 3 | Backend remoto en Cloud Storage | `plan-3.txt` · `plan-3a.txt` | `No changes` · `1 to add` |
| 4 | Modificar instancias y crear la tercera | `plan-4.txt` | `1 add, 2 change` |
| 5 | Destruir un recurso | `plan-5.txt` | `1 to destroy` |
| 6 | Módulo de red del Registry | `plan-6.txt` · `plan-6a.txt` | `2 change` · `3 to add` |
| 7 | Regla de firewall | `plan-7.txt` | `1 to add` |

---

## Bitácora

### GSP233 — hecho

**El resultado:** `Plan: 7 to add`, balanceador en `34.186.57.192`, y NGINX respondiendo — [captura](evidencia/gsp233-nginx.jpg) y `nginx-respuesta.txt` con el HTML pedido por `curl`.

**El grafo entre los dos providers.** El criterio pide ver que `kubernetes_service` depende del clúster, y la respuesta tiene un matiz: **no hay flecha directa**. Lo que hay es

```
kubernetes_service.nginx -> kubernetes_namespace.staging -> google_container_cluster.default
```

una dependencia **transitiva**, más una segunda ruta que el grafo no dibuja: el bloque `provider "kubernetes"` se configura con `google_container_cluster.default.endpoint`, así que ni siquiera se puede hablar con Kubernetes antes de que el clúster exista. Por eso guardé `grafo.dot` además del plan: el plan dice *qué* se crea, el grafo dice *en qué orden y por qué*.

**Qué me costó:** nada se rompió, y eso tiene su lección. En el GSP497 el `apply` estaba escondido dentro de un `make` y hubo que leer el script para capturar el plan a tiempo; aquí el lab manda `terraform apply` directo. Lo que sí hice por costumbre del anterior fue correr `terraform graph` antes del apply — no lo pedía el lab, y acabó siendo lo que respondió bien al criterio.

### GSP497 — hecho

**Los números cuadran:** `Plan: 5 to add` y `Destroy complete! Resources: 5 destroyed.` Los cinco recursos están nombrados uno por uno en [`02-gsp497/README.md`](02-gsp497/README.md).

**Lo que casi me cuesta la evidencia:** el lab manda `make create`, y ese comando hace el `apply` por dentro. Lanzado a secas, cuando quieres guardar el plan ya es tarde: después del apply, `terraform plan` dice `No changes`. Leí `scripts/create.sh` antes de ejecutarlo, repetí a mano su preparación (generar `tfvars`, habilitar APIs, `init`), capturé el plan, y recién entonces dejé que `make create` trabajara.

**Lo que me confundió:** fui a Monitoring → Alerting demasiado pronto y la lista salía vacía. Pensé que había fallado algo. No: el clúster seguía creándose y la política de alerta es de lo último en aparecer. Un `terraform state list` me lo habría dicho al instante, en vez de mirar una pantalla vacía.

**Detalle del teardown:** `plan-inicial.txt` salió limpio porque se pidió con `-no-color`, pero `make teardown` llama a Terraform por dentro y no deja pasarle ese flag, así que `destroy.txt` trae códigos de color. No lo edité: va tal cual, y al lado está `destroy-sin-color.txt` para poder leerlo.

### GSP345 — hecho, 100/100

El detalle tarea por tarea está en [`03-gsp345/README.md`](03-gsp345/README.md). Lo que me llevo:

**Importar antes de escribir.** El orden intuitivo es escribir el `.tf` y después importar, y no funciona: el estado importado trae los valores reales, y si el `.tf` dice otra cosa, Terraform quiere **recrear** la instancia. Por eso `show-tras-import.txt` está en la carpeta: es la fuente de verdad desde la que se corrigió el código.

**Lo que no salió perfecto, y lo digo.** El criterio pide que `plan-2.txt` diga `No changes`. El mío dice `0 to add, 2 to change, 0 to destroy`. Lo importante: **no recrea nada**, que es el caso fatal. Pero de los tres cambios que propone, uno —`metadata_startup_script`— sí toca la instancia, y encima estaba **vacío** en el `.tf`: ruido que las instancias reales no tenían. Si lo hubiera borrado, el plan habría salido limpio. Lo correcto era quitar del `.tf` todo lo que el estado real no tuviera, no solo ajustar lo que sí.

**El orden del backend.** El bucket tiene que existir antes de guardar el estado dentro: primero `apply` con backend local, después `init -migrate-state`. Al migrar, Terraform ofrece **copiar** el estado local al remoto; si respondes que no, arrancas vacío y el siguiente plan querría crear otra vez lo que ya existe. `plan-3.txt` dice `No changes`, así que la migración conservó el estado.

**Destruir borrando el bloque, no con `-target`.** Con `-target` el recurso desaparece pero el código no se entera, y el `.tf` entregado deja de corresponder al estado.

---

## Uso de IA

_Qué le pedí, qué me dio, qué corregí._

**Lo que le pedí antes de empezar:** la estructura y los `.tf` del Challenge Lab, y un runbook con los comandos en orden y los puntos donde guardar cada `plan-<n>.txt`. En los labs 1 y 2, además, ir leyendo conmigo el enunciado de Google y avisarme de dónde parar a capturar evidencia.

**Lo que resultó bien:**

- Los archivos venían **validados con Terraform de verdad**, no escritos a ojo: `terraform fmt -check` limpio y `terraform validate` → `Success`, con el provider `hashicorp/google` descargado, y el módulo del Registry comprobado con los parámetros exactos que aparecen en `main.tf`.
- En el GSP497, leer `scripts/create.sh` **antes** de ejecutar `make create` fue lo que salvó la evidencia: ese comando hace el `apply` por dentro, y después del apply el plan ya dice `No changes`.
- En el GSP233, correr `terraform graph` no lo pedía el lab, y acabó siendo lo que responde bien al criterio sobre la dependencia del Service con el clúster.

**Lo que hubo que corregir:**

- Los atributos de `google_compute_instance` venían marcados como `COMPROBAR` a propósito, no rellenados. El criterio de la tarea 2 es que el plan tras el import diga `No changes`, y eso **no se adivina**: hay que importar primero y copiar los valores de `terraform show`. Que vinieran sin rellenar fue lo correcto.
- Aun así, **ahí se me escapó el único fallo real**: quedó un `metadata_startup_script` vacío en el `.tf` que las instancias importadas no tenían, y por eso `plan-2.txt` dice `2 to change` en vez de `No changes`. Está explicado en [`03-gsp345/README.md`](03-gsp345/README.md). La lección es que corregir el `.tf` tras el import no es solo ajustar lo que no coincide: también es **borrar lo que el estado real no tiene**.
- En el runbook, `tf_instance_3` usaba dos variables que el módulo no declaraba. Se detectó revisando los archivos antes del lab, no durante: habría fallado en la tarea 4 con el reloj corriendo.
- Los enlaces a los labs que trae el enunciado del curso **no coinciden**: el que dice GSP233 lleva al GSP497. Hubo que buscarlos por ID en el catálogo.

**Qué me llevo sobre usar IA aquí:** sirvió de verdad para preparar y para leer salidas largas deprisa, que es exactamente lo que el enunciado recomienda. Donde falló fue en el único sitio donde el enunciado avisaba que iba a fallar: los atributos del recurso importado.
