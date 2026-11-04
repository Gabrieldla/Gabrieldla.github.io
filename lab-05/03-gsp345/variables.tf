# Los valores reales te los da el lab cuando pulsas Start Lab, y cambian en cada
# ejecucion. NO hay valores por defecto a proposito: prefiero que Terraform me
# pregunte a que aplique con un project_id que no es el mio.
#
# Rellena terraform.tfvars nada mas abrir Cloud Shell (ver GUIA.md).

variable "project_id" {
  description = "El proyecto temporal que crea el lab. Sale en el panel izquierdo de Google Cloud."
  type        = string
}

variable "region" {
  description = "La region que pide el enunciado del lab."
  type        = string
}

variable "zone" {
  description = "La zona que pide el enunciado. Tiene que estar DENTRO de la region de arriba."
  type        = string
}

variable "nombre_bucket" {
  description = "Nombre del bucket del estado remoto (tarea 3). Lo da el enunciado y es unico a nivel mundial."
  type        = string
}

variable "network_name" {
  description = "Nombre de la red VPC que crea el modulo del Registry (tarea 6). Lo da el enunciado."
  type        = string
  default     = "tf-vpc"
}
