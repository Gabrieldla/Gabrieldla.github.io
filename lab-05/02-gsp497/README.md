# GSP497 — Cloud Operations for GKE

Lab completado el **05/11/2026**. Clúster de GKE con una aplicación de ejemplo, creado y destruido con Terraform, y métricas de Prometheus llegando a Cloud Monitoring.

## Qué hay aquí

| Archivo | Qué es |
|---|---|
| `plan-inicial.txt` | El plan **antes** del primer apply. Con `-no-color`, sin códigos de escape |
| `destroy.txt` | La salida del teardown, tal como salió |
| `destroy-sin-color.txt` | Lo mismo, con los códigos de color quitados, para poder leerlo |
| `*.tf` | Los archivos de Terraform del repositorio que clona el lab |

## Los números cuadran

```
plan-inicial.txt:  Plan: 5 to add, 0 to change, 0 to destroy.
destroy.txt:       Destroy complete! Resources: 5 destroyed.
```

**5 creados, 5 destruidos.** Y son estos cinco, nombrados en el plan:

```
google_container_cluster.primary
google_monitoring_alert_policy.prometheus_mem_alloc
google_project_service.container
google_project_service.logging
google_project_service.monitoring
```

Los tres `google_project_service` no son infraestructura: son **APIs de Google Cloud que se habilitan**. Terraform las administra como un recurso más, y por eso aparecen en la cuenta.

## Por qué hay dos archivos del destroy

El plan se guardó con `terraform plan -no-color`, así que `plan-inicial.txt` sale limpio. El teardown **no se puede pedir igual**: el lab lo lanza con `make teardown`, que llama a `scripts/teardown.sh`, y ese script invoca a Terraform por dentro sin dejar pasarle `-no-color`. El resultado es que `destroy.txt` trae códigos de color en 428 de sus líneas.

No lo edité: `destroy.txt` es la captura tal cual, y al lado va `destroy-sin-color.txt`, que es el mismo contenido con los escapes quitados. La evidencia original se queda intacta y además se puede leer.

## El plan antes del apply: lo que no es obvio

El lab manda ejecutar `make create`, y ese comando **hace el `apply` por dentro**. Si uno lo lanza sin más, cuando quiere guardar el plan ya es tarde: después del apply, `terraform plan` dice `No changes` y no sirve como evidencia.

Lo que hice fue leer `scripts/create.sh` antes de ejecutarlo. Hace cuatro cosas: genera `terraform.tfvars`, prepara el manifiesto de Prometheus con `sed`, habilita las APIs y recién entonces corre `init` y `apply`. Así que repetí a mano las tres primeras, capturé el plan, y dejé que `make create` hiciera el trabajo de verdad.

## Lo que demuestra la captura de Monitoring

`../evidencia/gsp497-monitoring.png` es la política de alerta **que creó Terraform**, no una hecha a mano: `google_monitoring_alert_policy.prometheus_mem_alloc` está en el plan de arriba.

En la captura se ve la condición (`mem alloc above 12`) y, debajo, las series que llegaron de verdad:

| Contenedor | Namespace | Valor |
|---|---|---|
| `node-cache` | kube-system | 7.079 M |
| `prometheus` | default | **16.111 M** |

El pod de `prometheus` está por encima del umbral de 12, que es justo el caso que la política vigila. Eso es lo que pide el reto: una métrica que **nació en un endpoint de Prometheus** y terminó siendo una métrica nativa de Cloud Monitoring, con alertas encima, sin instalar nada aparte.

## Qué me costó

Lo que más tiempo me quitó fue algo que no era un error: fui a **Monitoring → Alerting** demasiado pronto y la lista salía vacía. Di por hecho que algo había fallado. No: `make create` todavía estaba creando el clúster, y la política de alerta es de los últimos recursos en aparecer. Un `terraform state list` lo habría respondido en un segundo.
