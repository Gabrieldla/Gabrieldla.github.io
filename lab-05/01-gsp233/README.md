# GSP233 — Deploy Kubernetes Load Balancer Service with Terraform

Lab completado el **05/11/2026**, con **100 / 100**. Un clúster de GKE y, dentro, NGINX expuesto con un Service de tipo LoadBalancer — todo desde Terraform, con **dos providers conviviendo**.

## Qué hay aquí

| Archivo | Qué es |
|---|---|
| `plan-inicial.txt` | El plan **antes** del apply, con `-no-color` |
| `grafo.dot` | `terraform graph`: el grafo de dependencias |
| `main.tf`, `k8s.tf`, `versions.tf` | El código del lab |
| `outputs.txt` | Las salidas tras el apply, con la IP del balanceador |
| `nginx-respuesta.txt` | Lo que devolvió NGINX al hacerle `curl` |

## El resultado

```
Plan: 7 to add, 0 to change, 0 to destroy.
```

Siete recursos, y el balanceador quedó en **34.186.57.192**. La [captura del navegador](../evidencia/gsp233-nginx.jpg) muestra el *Welcome to nginx!* servido desde esa IP, y `nginx-respuesta.txt` es el mismo HTML pedido con `curl`.

## Los dos providers, que es el punto del lab

`main.tf` usa el provider `google` para la red, la subred y el clúster. `k8s.tf` declara un segundo provider, `kubernetes`, y aquí está lo interesante:

```hcl
provider "kubernetes" {
  host = google_container_cluster.default.endpoint
  client_certificate = base64decode(
    google_container_cluster.default.master_auth[0].client_certificate,
  )
  ...
}
```

**El provider se configura con atributos de un recurso que todavía no existe.** No se puede hablar con el clúster antes de crearlo, así que Terraform tiene que resolver un orden: primero la red, luego el clúster, y recién entonces configurar el provider de Kubernetes y crear el namespace, el Service y el controlador de réplicas.

## La dependencia que pedía el criterio, y el matiz

El criterio dice que en el plan *"se ve que el recurso `kubernetes_service` depende del clúster"*. Lo comprobé con el grafo, y la respuesta tiene un matiz que vale la pena contar: **no hay una flecha directa.**

```
kubernetes_service.nginx -> google_compute_address.default
kubernetes_service.nginx -> kubernetes_namespace.staging
kubernetes_namespace.staging -> google_container_cluster.default
```

La dependencia existe, pero es **transitiva**: el Service depende del namespace, y el namespace sí depende del clúster. Más una segunda ruta que el grafo no dibuja como arista normal: la configuración del provider lee `google_container_cluster.default.endpoint`, así que ni siquiera se puede *hablar* con Kubernetes antes de que el clúster exista.

Decir "el Service depende del clúster" es correcto en el resultado, pero si uno busca la flecha directa en el grafo, no está. Por eso guardé `grafo.dot` y no solo el plan: **el plan dice qué se va a crear, el grafo dice en qué orden y por qué**.

## Qué me costó

Nada se rompió, y eso tiene su propia lección. En el lab anterior (GSP497) el `apply` estaba escondido dentro de un `make create`, y hubo que leer el script para poder capturar el plan a tiempo. Aquí el lab manda `terraform apply` directo, así que capturar el plan fue poner un comando antes.

Lo que sí hice distinto por costumbre del anterior: correr `terraform graph` antes del apply. No lo pedía el lab, pero es lo que acabó respondiendo bien la pregunta del criterio.
