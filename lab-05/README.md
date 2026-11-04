# LAB-05: Terraform en Google Cloud

> ⚠️ **Entrega en curso.** Los `.tf` del Challenge Lab y la [guía de ejecución](GUIA.md) están listos y validados; los tres labs de Google Skills están pendientes de correr. Las tablas de abajo se rellenan con la evidencia real, no antes.

## Evidencia

| Lab | Puntaje | Captura | Carpeta |
|-----|---------|---------|---------|
| GSP233 — Deploy Kubernetes Load Balancer Service with Terraform | — / 100 | `evidencia/gsp233.png` | [`01-gsp233/`](01-gsp233/) |
| GSP497 — Cloud Operations for GKE | — / 100 | `evidencia/gsp497.png` | [`02-gsp497/`](02-gsp497/) |
| GSP345 — Build Infrastructure with Terraform: Challenge Lab | — / 100 | `evidencia/gsp345.png` | [`03-gsp345/`](03-gsp345/) |

**Perfil público de Google Skills:** _(pendiente)_

### Challenge Lab, tarea por tarea

| Tarea | Qué hace | Plan | Hecha |
|-------|----------|------|-------|
| 2 | Importar `tf-instance-1` y `tf-instance-2` | `plan-2.txt` | ☐ |
| 3 | Backend remoto en Cloud Storage | `plan-3.txt` | ☐ |
| 4 | Modificar instancias y crear la tercera | `plan-4.txt` | ☐ |
| 5 | Destruir un recurso | `plan-5.txt` | ☐ |
| 6 | Módulo de red del Registry | `plan-6.txt` | ☐ |
| 7 | Regla de firewall | `plan-7.txt` | ☐ |

---

## Bitácora

### GSP233

_Qué hice. Qué me costó. Qué cambiaría._

Puntos a responder cuando lo corra:

- La IP externa del Service y la prueba de que NGINX respondía.
- **El grafo entre los dos providers:** por qué `kubernetes_service` no puede crearse antes que el clúster, y dónde se ve esa dependencia en el plan.

### GSP497

- Cuántos recursos creó el plan inicial y cuántos destruyó el teardown, y si los números cuadraron.
- La captura de Cloud Monitoring con las métricas de Prometheus.

### GSP345

- **Tarea 2, la importación.** Qué atributos tuve que ajustar en el `.tf` para que `plan-2.txt` dijera `No changes`, y cómo los averigüé (leyendo `show-tras-import.txt`, no adivinando).
- **Tarea 3, el backend.** Qué pasó al correr `terraform init -migrate-state` y qué habría pasado si respondía que no.
- Qué versión del módulo del Registry usé y por qué está fija.
- Qué abrí exactamente en la regla de firewall y por qué no más.

---

## Uso de IA

_Qué le pedí, qué me dio, qué corregí._

Lo que pedí y lo que recibí, antes de correr los labs:

- **La estructura y los `.tf` del Challenge Lab**, con los módulos `instances` y `storage`, y la [guía de ejecución](GUIA.md) con los comandos en orden y los puntos donde guardar cada `plan-<n>.txt`.
- Los archivos están **validados con Terraform de verdad**, no escritos a ojo: `terraform fmt -check` limpio y `terraform validate` → `Success! The configuration is valid.`, con el provider `hashicorp/google` descargado. El módulo del Registry (`terraform-google-modules/network/google` 18.3.1) también se descargó y validó con los parámetros que aparecen en `main.tf`.

Lo que **no** acepté tal cual, que es lo que el enunciado avisa que la IA hace mal:

- **Los atributos de `google_compute_instance` quedaron marcados como `COMPROBAR`.** La IA propuso valores plausibles (`e2-micro`, Debian 12, red `default`), pero el criterio de la tarea 2 es que el plan después del import diga `No changes`, y eso no se consigue adivinando. El método correcto, y el que está escrito en los archivos, es importar primero y copiar los valores reales de `terraform show`.
- **La versión del módulo del Registry va fija** (`18.3.1`), con la nota de que si el enunciado del lab pide otra, manda el enunciado.
- **La regla de firewall abre solo `tcp/80`**, nada más, y apunta a la red del módulo en vez de a `default`.
- Ningún `apply` aparece antes de su `plan` correspondiente.

_(Completar después de correr los labs: qué de esto resultó estar mal y qué tuve que corregir sobre la marcha.)_
