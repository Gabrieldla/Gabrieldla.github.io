variable "project_id" {
  type = string
}

variable "region" {
  description = "El bucket es regional. Tiene que coincidir con la region que pide el enunciado."
  type        = string
}

variable "nombre_bucket" {
  description = "El nombre del bucket, que te da el enunciado del lab. Es unico a nivel MUNDIAL, por eso suele llevar el id del proyecto dentro."
  type        = string
}
