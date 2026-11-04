output "nombre" {
  description = "Nombre del bucket, para copiarlo al bloque backend sin volver a escribirlo a mano."
  value       = google_storage_bucket.estado.name
}
