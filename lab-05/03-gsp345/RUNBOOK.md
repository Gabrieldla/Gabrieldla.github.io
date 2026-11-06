# Runbook del Challenge Lab GSP345

**14 de los 20 puntos del LAB-05.** Siete tareas, 90 minutos, y el lab **no trae instrucciones**: te da un escenario y te califica por tarea.

Esto es la lista de comandos en orden, con los puntos donde hay que **parar a mirar** y las trampas que ya están resueltas en los `.tf` de esta carpeta.

---

## ANTES de pulsar *Start Lab*

Lee el enunciado entero y **apunta estos cinco valores**, que cambian en cada ejecución:

| Valor | Dónde sale |
|---|---|
| `project_id` | Panel del lab, o arriba en la consola |
| `region` | El enunciado lo dice |
| `zone` | El enunciado lo dice. **Tiene que estar dentro de esa región** |
| Nombre del bucket | El enunciado lo dice. Es único a nivel mundial |
| Nombre de la red VPC | El enunciado lo dice (suele ser `tf-vpc`) |

También apunta: los **nombres exactos** de las instancias (suelen ser `tf-instance-1` y `tf-instance-2`), el nombre de la tercera, y el `machine_type` al que hay que cambiarlas.

> ⚠️ **Si el enunciado pide una versión concreta del módulo del Registry, manda la suya**, no la que yo dejé puesta.

---

## Minuto 0 — Traer los archivos

Ya están escritos y validados en este repositorio. En Cloud Shell:

```bash
cd ~
git clone --depth 1 https://github.com/Gabrieldla/Gabrieldla.github.io.git repo
cp -r repo/lab-05/03-gsp345 ~/gsp345
cd ~/gsp345
cp terraform.tfvars.ejemplo terraform.tfvars
nano terraform.tfvars
```

Rellena los cinco valores. Guardar en nano: `Ctrl+O`, `Enter`, `Ctrl+X`.

```bash
terraform init
```

> **Si Terraform no está instalado** (el lab a veces no lo trae), el bloque de instalación está en [GUIA.md](../GUIA.md).

---

## TAREA 2 — Importar las instancias *(3 pts)* ⭐ la delicada

Las dos instancias **ya existen**: el lab las creó a mano antes de empezar. Aquí no se crean, se importan.

**El criterio del profesor:** `plan-2.txt` tiene que decir `No changes`. Si dice que va a destruir y recrear las instancias, **la tarea no suma aunque Google te dé los puntos**.

```bash
terraform import module.instances.google_compute_instance.tf_instance_1 \
  PROJECT_ID/ZONA/tf-instance-1
terraform import module.instances.google_compute_instance.tf_instance_2 \
  PROJECT_ID/ZONA/tf-instance-2
```

**Ahora para y mira lo que de verdad hay:**

```bash
terraform show -no-color > show-tras-import.txt
terraform state list > state-list.txt
grep -E "machine_type|image|network " show-tras-import.txt
```

Abre `modules/instances/instances.tf` y **copia ahí los valores reales** que acabas de ver: `machine_type`, la imagen del `boot_disk` y el `network_interface`. Los que dejé puestos son los más probables, **no los des por buenos**.

```bash
terraform plan -no-color > plan-2.txt
grep -E "No changes|must be replaced|will be destroyed" plan-2.txt
```

| Qué sale | Qué significa |
|---|---|
| `No changes` | ✅ listo, sigue |
| `must be replaced` o `will be destroyed` | ❌ **no apliques**. Vuelve al `show` y ajusta el atributo que no coincide |

> **Por qué este orden.** Lo intuitivo es escribir el `.tf` y después importar. No funciona: el estado importado trae los valores reales, y si tu `.tf` dice otra cosa, Terraform quiere recrear la instancia. El estado es la fuente de verdad, no lo que tú creas.

---

## TAREA 3 — Backend remoto *(1 pt)*

**El orden no se puede invertir:** el bucket tiene que existir antes de guardar el estado dentro.

```bash
terraform apply -auto-approve -no-color | tee apply-3.txt
```

Eso crea el bucket. Ahora **descomenta el bloque `backend "gcs"` en `main.tf`** y pon el nombre del bucket. Luego:

```bash
terraform init -migrate-state
```

Responde **`yes`** cuando pregunte.

```bash
terraform plan -no-color > plan-3.txt
```

> **Qué pasa en `-migrate-state`, que te lo pueden preguntar:** Terraform ve un estado local y uno remoto vacío, y ofrece **copiar** el local al remoto. Si dices que no, arrancas con un estado vacío y el siguiente plan querría crear otra vez todo lo que ya existe.

---

## TAREA 4 — Modificar *(3 pts)*

Dos cosas: cambiar el `machine_type` de las instancias importadas, y crear la tercera. **Los valores exactos los da el enunciado.**

1. En `modules/instances/instances.tf`, cambia el `machine_type` de `tf_instance_1` y `tf_instance_2`
2. **Descomenta el bloque de `tf_instance_3`** y ajusta nombre y tipo

```bash
terraform plan -no-color > plan-4.txt
terraform apply -auto-approve -no-color | tee apply-4.txt
```

> **Trampa resuelta:** si falla con *"instance must be stopped"*, es que falta `allow_stopping_for_update = true`. Ya está puesto en los tres bloques — Terraform no puede redimensionar una instancia encendida y aborta en vez de apagarla.

---

## TAREA 5 — Destruir un recurso *(1 pt)*

```bash
# BORRA el bloque de tf_instance_3 del .tf. NO uses destroy -target.
terraform plan -no-color > plan-5.txt
grep "to destroy" plan-5.txt     # debe decir: 1 to destroy
terraform apply -auto-approve -no-color | tee apply-5.txt
```

> **Por qué no `-target`:** destruye sin dejar rastro en el código, y entonces el `.tf` que entregas ya no corresponde al estado. El profesor compara las dos cosas.

---

## TAREA 6 — Módulo del Registry *(3 pts)*

1. **Descomenta el bloque `module "red"` en `main.tf`**
2. Comprueba que el nombre de la red y la versión coinciden con lo que pide el enunciado

```bash
terraform init      # hace falta: hay un modulo nuevo que descargar
terraform plan -no-color > plan-6.txt
terraform apply -auto-approve -no-color | tee apply-6.txt
```

> La versión va **fija** (`18.3.1`, probada: descarga y valida). Si el enunciado pide otra, **pon la suya**. No fijarla es uno de los errores que el enunciado avisa.

---

## TAREA 7 — Firewall *(3 pts)*

1. **Descomenta `google_compute_firewall` en `main.tf`**

```bash
terraform plan -no-color > plan-7.txt
terraform apply -auto-approve -no-color | tee apply-7.txt
```

> **Solo `tcp/80` desde `0.0.0.0/0`**, y apuntando a `module.red.network_name`, **nunca a `default`**. Si la cuelgas de `default`, la tarea 6 deja de contar. Y no agregues el 22 ni `all`: abrirla de más es otro de los errores que avisa el enunciado.

---

## ANTES de pulsar *End Lab* ⚠️

Cuando el lab termina, el proyecto y Cloud Shell desaparecen **con todo dentro**.

```bash
cd ~/gsp345
terraform state list > state-list-final.txt
mkdir -p ~/evidencia-gsp345
cp -r main.tf variables.tf modules plan-*.txt apply-*.txt \
      state-list*.txt show-tras-import.txt ~/evidencia-gsp345/ 2>/dev/null
ls -R ~/evidencia-gsp345
cd ~ && tar czf evidencia-gsp345.tar.gz evidencia-gsp345
```

Descargar: menú **⋮** → **Download** → ruta completa:

```
/home/TU_USUARIO/evidencia-gsp345.tar.gz
```

`TU_USUARIO` sale en el prompt de Cloud Shell, antes de la `@`.

### Lo que tiene que venir dentro

- `main.tf`, `variables.tf`, `modules/instances/*`, `modules/storage/*`
- **`plan-2.txt` … `plan-7.txt`** — uno por tarea
- `state-list.txt` y `state-list-final.txt`
- `show-tras-import.txt`

> **Sin los planes, las tareas no cuentan**, aunque Google te las haya marcado. Es literal: *"Una tarea suma si se cumplen las tres cosas: Google la marcó, su `plan-<n>.txt` está en tu carpeta y los `.tf` entregados son los que producen ese plan."*

### Y las capturas

- El **puntaje final con el detalle por tarea** visible
- La página **Progress** de tu cuenta, con tu nombre y la fecha

---

## Resumen de lo que no se puede olvidar

| | |
|---|---|
| 🔴 **Un `plan-<n>.txt` por tarea** | Sin eso, la tarea no suma |
| 🔴 **`plan-2.txt` debe decir `No changes`** | Si no, la importación no quedó bien |
| 🔴 **Descargar antes de End Lab** | Después no hay vuelta atrás |
| 🟡 Versión del módulo fija | La del enunciado manda |
| 🟡 Firewall solo `tcp/80` | Abrirlo de más resta |
| 🟡 Tarea 5 sin `-target` | El código debe reflejar el estado |
