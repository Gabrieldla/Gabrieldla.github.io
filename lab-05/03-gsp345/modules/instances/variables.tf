variable "project_id" {
  type = string
}

variable "zone" {
  description = "Tiene que ser la MISMA zona en la que ya existen tf-instance-1 y tf-instance-2, o el import no coincide."
  type        = string
}
