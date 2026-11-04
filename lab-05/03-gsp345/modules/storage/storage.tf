# El bucket de la tarea 3: aqui va a vivir el estado remoto.
#
# Hay un orden que no se puede saltar, y es la parte que mas confunde del lab:
# el bucket tiene que EXISTIR antes de que Terraform pueda guardar el estado
# dentro. Asi que primero se crea con el backend local (apply normal), y DESPUES
# se agrega el bloque backend "gcs" y se corre `terraform init -migrate-state`.
#
# Si pones el backend antes de crear el bucket, `init` falla porque intenta
# escribir en algo que no esta.

resource "google_storage_bucket" "estado" {
  name     = var.nombre_bucket
  project  = var.project_id
  location = var.region

  # El lab lo borra todo al terminar, pero esto es lo correcto igual: sin esto,
  # un `terraform destroy` se lleva por delante el bucket que guarda el estado,
  # y con el, el estado.
  force_destroy = true

  # Obligatorio desde hace varias versiones del provider: sin esto, el bucket
  # queda con ACL antiguas y Google lo marca como no recomendado.
  uniform_bucket_level_access = true
}
