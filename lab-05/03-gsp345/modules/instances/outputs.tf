output "instancias" {
  description = "Nombres de las instancias que administra este modulo, para comprobar de un vistazo que el import quedo bien."
  value = [
    google_compute_instance.tf_instance_1.name,
    google_compute_instance.tf_instance_2.name,
  ]
}
