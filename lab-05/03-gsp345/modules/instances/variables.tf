variable "project_id" {
  type = string
}

variable "zone" {
  description = "Tiene que ser la MISMA zona en la que ya existen tf-instance-1 y tf-instance-2, o el import no coincide."
  type        = string
}

# Las dos de abajo solo hacen falta a partir de la TAREA 4, cuando se crea la
# tercera instancia y hay que colgarla de la red del modulo del Registry.
# Tienen valor por defecto para que el modulo siga funcionando en las tareas 2 y
# 3, cuando esa red todavia no existe.

variable "network_name" {
  description = "Red a la que se conecta tf_instance_3. En la tarea 6 pasa a ser la del modulo del Registry."
  type        = string
  default     = "default"
}

variable "subnetwork_name" {
  description = "Subred de tf_instance_3. Vacia mientras la red sea la default, porque default ya trae subred propia por region."
  type        = string
  default     = null
}
