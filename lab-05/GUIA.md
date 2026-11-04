# Guía para correr los tres labs

Esto es lo que tengo abierto en una pestaña **mientras** corro los labs. No es la bitácora (esa va en `README.md`, y se escribe después): es la lista de comandos y, sobre todo, **en qué momento exacto guardar cada evidencia**, porque cuando el reloj llega a cero el proyecto desaparece con todo adentro.

## Antes de pulsar Start Lab en cualquiera de los tres

- Ventana de **incógnito**. Con la cuenta personal de Google en la misma ventana, el lab falla.
- Esta guía abierta al lado.
- Tener claro que **la evidencia se guarda durante el lab, no al final**. Si el reloj se acaba, no hay segunda oportunidad: hay que repetir el lab y gastar otro crédito.

## Cómo descargar un archivo desde Cloud Shell

En el menú de los tres puntos de Cloud Shell: **Download**, y escribes la ruta. O más cómodo, al terminar cada lab:

```bash
# Empaqueta todo lo que hay que guardar en un solo archivo y lo descargas de una vez
cd ~
tar czf evidencia.tar.gz <carpeta-del-lab>
```

Y luego *Download* → `evidencia.tar.gz`.

---

# Lab 1 — GSP233 (3 pts)

Este trae pasos. **Síguelos tal cual los da el lab**; lo único que agrego es dónde parar a guardar.

| Cuándo | Qué hacer |
|---|---|
| Después de `terraform init`, **antes** del primer `apply` | `terraform plan -no-color > plan-inicial.txt` |
| Después del `apply` | Apuntar la **IP externa** del Service y hacerle `curl` |
| Al final | Descargar los `.tf` y `plan-inicial.txt` a `lab-05/01-gsp233/` |

```bash
# La IP externa del Service, que va en la bitácora
kubectl get service nginx -o wide

# Y la prueba de que NGINX responde
curl -s -o /dev/null -w "%{http_code}\n" http://<IP-EXTERNA>/
```

> El criterio del profesor: *"en tu `plan-inicial.txt` se pueden contar los recursos con `+` y se ve que el recurso `kubernetes_service` depende del clúster"*. Eso sale solo si guardas el plan **antes** del apply. Después del apply, el plan dice "No changes" y no sirve de evidencia.

**Captura del puntaje:** la página del lab al 100 %, con tu usuario y la fecha visibles. Guárdala como `lab-05/evidencia/gsp233.png`.

---

# Lab 2 — GSP497 (3 pts)

También trae pasos. Lo que cambia es que **este lab no cierra hasta que destruyes todo**.

| Cuándo | Qué hacer |
|---|---|
| Antes del primer `apply` | `terraform plan -no-color > plan-inicial.txt` |
| Con la app corriendo | Captura de **Cloud Monitoring** con las métricas de Prometheus |
| En el teardown | `terraform destroy -auto-approve -no-color \| tee destroy.txt` |
| Al final | Descargar `.tf`, `plan-inicial.txt` y `destroy.txt` a `lab-05/02-gsp497/` |

> El criterio: *"`destroy.txt` termina con `Destroy complete!` y el número de recursos destruidos coincide con el de recursos creados en `plan-inicial.txt`"*. Así que cuenta los dos números y compáralos tú antes de entregar:

```bash
grep -c "^  +" plan-inicial.txt     # recursos que se iban a crear
tail -3 destroy.txt                 # "Destroy complete! N resources destroyed."
```

Si no cuadran, explícalo en la bitácora en vez de esconderlo: a veces el lab crea cosas fuera de Terraform.

---

# Lab 3 — GSP345, el Challenge (14 pts)

**Este no trae pasos y vale el 70 % de la nota.** Los `.tf` ya están escritos en `03-gsp345/`. El plan es: pegarlos, rellenar cuatro valores, y seguir el orden de abajo.

## Minuto 0: preparar

```bash
mkdir ~/gsp345 && cd ~/gsp345
# Pega aquí el contenido de 03-gsp345/ (main.tf, variables.tf, modules/)
cp terraform.tfvars.ejemplo terraform.tfvars
nano terraform.tfvars    # rellena project_id, region, zone, nombre_bucket
```

Los cuatro valores salen del **enunciado del lab** y del panel de Google Cloud. **La zona tiene que ser la misma en la que ya existen las instancias** (Compute Engine → VM instances).

```bash
terraform init
```

## Tarea 2 — Importar (3 pts). La más delicada

El criterio es que `plan-2.txt` diga **`No changes`**. Si dice que va a recrear las instancias, la tarea **no suma aunque Google te dé los puntos**.

```bash
terraform import module.instances.google_compute_instance.tf_instance_1 \
  <project_id>/<zone>/tf-instance-1
terraform import module.instances.google_compute_instance.tf_instance_2 \
  <project_id>/<zone>/tf-instance-2

# AHORA mira qué hay de verdad en el estado
terraform show -no-color > show-tras-import.txt
terraform state list > state-list.txt
```

**Abre `show-tras-import.txt`** y copia a `modules/instances/instances.tf` los valores reales de `machine_type`, la imagen del `boot_disk` y el `network_interface`. Los que dejé puestos son los más probables, **no los des por buenos**.

```bash
terraform plan -no-color > plan-2.txt
grep -E "No changes|will be destroyed|must be replaced" plan-2.txt
```

- Sale `No changes` → listo.
- Sale `must be replaced` o `will be destroyed` → **no apliques**. Vuelve al `show` y ajusta el atributo que no coincide.

> Esto es lo que el profesor va a preguntar en la oral: *qué atributos exige `google_compute_instance` para que el import coincida*. La respuesta honesta es que no se adivinan: se leen del estado importado.

## Tarea 3 — Backend remoto (1 pt)

Orden que **no** se puede invertir: el bucket tiene que existir antes de guardar el estado dentro.

```bash
terraform apply -auto-approve -no-color | tee apply-bucket.txt   # crea el bucket
# Ahora descomenta el bloque backend "gcs" en main.tf y pon el nombre del bucket
terraform init -migrate-state      # responde "yes" cuando pregunte
terraform plan -no-color > plan-3.txt
```

> Lo que pasa en `-migrate-state`: Terraform ve un estado local y uno remoto vacío, y ofrece **copiar** el local al remoto. Si dices que no, arrancas con un estado vacío y el siguiente plan querría crear otra vez todo lo que ya existe. Otra pregunta probable de la oral.

## Tarea 4 — Modificar (3 pts)

Dos cosas: cambiar el `machine_type` de las instancias que importaste, y crear la tercera. **El enunciado te dice el tipo y el nombre exactos.**

```bash
# descomenta tf_instance_3 en modules/instances/instances.tf y ajusta machine_type
terraform plan -no-color > plan-4.txt
terraform apply -auto-approve -no-color | tee apply-4.txt
```

> Si falla con *"instance must be stopped"*, es porque falta `allow_stopping_for_update = true`. Ya está puesto en los bloques.

## Tarea 5 — Destruir un recurso (1 pt)

```bash
# BORRA el bloque de tf_instance_3 del .tf. No uses destroy -target.
terraform plan -no-color > plan-5.txt     # debe decir: 1 to destroy
terraform apply -auto-approve -no-color | tee apply-5.txt
```

> Con `-target` destruyes sin dejar rastro en el código, y entonces el `.tf` que entregas ya no corresponde al estado. El profesor compara las dos cosas.

## Tarea 6 — Módulo del Registry (3 pts)

```bash
# descomenta el bloque module "red" en main.tf
terraform init      # hace falta: hay un módulo nuevo que descargar
terraform plan -no-color > plan-6.txt
terraform apply -auto-approve -no-color | tee apply-6.txt
```

> **Si el enunciado del lab pide una versión concreta del módulo, usa la suya, no la mía.** Yo dejé `18.3.1`, que es la última al 04/11/2026 y la probé: descarga y valida. Pero manda el enunciado.

## Tarea 7 — Firewall (3 pts)

```bash
# descomenta google_compute_firewall en main.tf
terraform plan -no-color > plan-7.txt
terraform apply -auto-approve -no-color | tee apply-7.txt
```

> Solo **tcp/80** desde `0.0.0.0/0`, y apuntando a la red del módulo, **no a `default`**. Abrirla de más es uno de los errores que el enunciado avisa.

## Antes de pulsar End Lab

```bash
terraform state list > state-list-final.txt
cd ~ && tar czf gsp345.tar.gz gsp345
```

Y *Download* → `gsp345.tar.gz`. Dentro tienen que venir:

- `main.tf`, `variables.tf`, `modules/instances/*`, `modules/storage/*`
- `plan-2.txt` … `plan-7.txt` (uno por tarea)
- `state-list.txt` y `state-list-final.txt`
- `show-tras-import.txt`

**Sin los planes no cuentan las tareas**, aunque Google te las haya marcado.

---

## Lo que NO se sube al repositorio

El enunciado lo pide expresamente, y el `.gitignore` de `03-gsp345/` ya lo cubre:

- `terraform.tfstate` y `terraform.tfstate.*`
- `.terraform/` y `.terraform.lock.hcl`
- `terraform.tfvars` (lleva el id de tu proyecto)
- Cualquier `.json` de cuenta de servicio
