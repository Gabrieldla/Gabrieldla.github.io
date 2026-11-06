# GSP345 — Build Infrastructure with Terraform: Challenge Lab

Completado el **06/11/2026**, con **100 / 100**. Siete tareas sin instrucciones: importar infraestructura creada a mano, migrar el estado a un backend remoto, modificar, destruir, usar un módulo del Registry y abrir una regla de firewall.

## Las tareas, una por una

| Tarea | Qué hace | Plan | Resultado del plan |
|-------|----------|------|--------------------|
| 2 | Importar `tf-instance-1` y `tf-instance-2` | `plan-2.txt` | `0 to add, 2 to change, 0 to destroy` |
| 3 | Backend remoto en Cloud Storage | `plan-3.txt` · `plan-3a.txt` | `No changes` · `1 to add` (el bucket) |
| 4 | Cambiar el tipo y crear la tercera instancia | `plan-4.txt` | `1 to add, 2 to change` |
| 5 | Destruir la tercera | `plan-5.txt` | `0 to add, 0 to change, 1 to destroy` |
| 6 | Red y subredes con un módulo del Registry | `plan-6.txt` · `plan-6a.txt` | `2 to change` · `3 to add` |
| 7 | Regla de firewall | `plan-7.txt` | `1 to add` |

Más `show-tras-import.txt`, `state-list.txt` (después de importar) y `state-list-final.txt`.

## El estado final

```
google_compute_firewall.tf-firewall
module.instances.google_compute_instance.tf-instance-1
module.instances.google_compute_instance.tf-instance-2
module.storage.google_storage_bucket.bucket
module.vpc.module.subnets.google_compute_subnetwork.subnetwork["us-west1/subnet-01"]
module.vpc.module.subnets.google_compute_subnetwork.subnetwork["us-west1/subnet-02"]
module.vpc.module.vpc.google_compute_network.network
```

`tf-instance-3` no está, y debe ser así: la tarea 5 la destruye. Las dos instancias que quedan son las **importadas**, no creadas por Terraform.

La regla de firewall abre **solo `tcp/80` desde `0.0.0.0/0`**, y apunta a la red `tf-vpc-643126` del módulo, **no a `default`**. Abrirla de más o colgarla de la red equivocada es uno de los errores que el enunciado avisa.

---

## Lo que no salió perfecto, y por qué lo digo

El criterio para la tarea 2 es que `plan-2.txt` diga `No changes` **o solo cambios que no toquen las instancias**. El mío dice:

```
Plan: 0 to add, 2 to change, 0 to destroy.
  # module.instances.google_compute_instance.tf-instance-1 will be updated in-place
      + allow_stopping_for_update  = true
      ~ metadata                   = { ... }
      + metadata_startup_script    = <<-EOT
      ~ terraform_labels           = { ... }
```

**Lo importante primero: `0 to destroy`, y `updated in-place`.** No recrea las instancias, que es el caso que el enunciado marca como fatal ("si dice que va a destruir y recrear las instancias, la importación no quedó bien aunque Google te haya dado los puntos").

De los tres cambios, dos son inocuos y uno no del todo:

| Cambio | ¿Toca la instancia? |
|---|---|
| `allow_stopping_for_update` | No. Es un flag que solo existe para Terraform |
| `terraform_labels` | No. Etiquetas que gestiona el propio Terraform |
| `metadata_startup_script` | **Sí.** Modifica los metadatos de la VM |

El `metadata_startup_script` que quedó declarado está **vacío**:

```hcl
metadata_startup_script = <<-EOT
EOT
```

Eso es ruido: declara un script de arranque que las instancias reales no tenían. **Si lo hubiera quitado del `.tf`, el plan habría dicho `No changes` limpio.** Lo correcto era leer `show-tras-import.txt` y borrar del `.tf` todo lo que el estado real no tuviera, no solo ajustar lo que sí.

Lo dejo escrito porque prefiero que se vea que entendí la diferencia a que parezca que no la noté. La tarea 2 está, pero no está perfecta.

---

## Lo que sí hice bien, y es lo que más me costó entender

**Importar antes de escribir.** El orden intuitivo es escribir el `.tf` y después importar. No funciona: el estado importado trae los valores reales de la instancia, y si tu `.tf` dice otra cosa, Terraform quiere recrearla. Por eso `show-tras-import.txt` está en esta carpeta: es la fuente de verdad desde la que se corrigió el `.tf`, no una suposición.

**El orden del backend.** El bucket tiene que existir **antes** de poder guardar el estado dentro, así que primero un `apply` con backend local y después `terraform init -migrate-state`. Al migrar, Terraform ve un estado local y uno remoto vacío y ofrece **copiar** el local al remoto; si uno responde que no, arranca con un estado vacío y el siguiente plan querría crear otra vez todo lo que ya existe. Por eso `plan-3.txt` dice `No changes`: la migración conservó el estado.

**Destruir borrando el bloque, no con `-target`.** `terraform destroy -target` elimina el recurso pero no deja rastro en el código, y entonces el `.tf` que se entrega ya no corresponde al estado. `plan-5.txt` muestra `1 to destroy` porque el bloque desapareció del archivo.

**La versión del módulo del Registry, fija.** No fijarla es otro de los errores que avisa el enunciado: ese módulo ha cambiado de versión mayor varias veces y entre una y otra se renombran variables; sin fijarla, lo que funciona hoy le falla a quien lo repita mañana.
