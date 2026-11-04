terraform {
  # El lab trae una version de Terraform ya instalada en Cloud Shell. Compruebala
  # con `terraform version` nada mas abrir, y ajusta esto si no cuadra.
  required_version = ">= 1.5"

  required_providers {
    google = {
      source = "hashicorp/google"
      # Fijada a proposito. Sin esto, Terraform baja la ultima que haya ese dia y
      # un atributo renombrado entre versiones mayores te rompe el plan a mitad
      # del lab, con el reloj corriendo. COMPROBAR cual trae Cloud Shell con
      # `terraform providers` despues del primer init.
      version = "~> 6.0"
    }
  }

  # ─── TAREA 3: el backend remoto ────────────────────────────────────────────
  # DESCOMENTAR SOLO DESPUES de que el bucket exista (tarea 3 del lab).
  # Orden correcto:
  #   1. apply con backend local  -> se crea el bucket
  #   2. descomentar este bloque, poner el nombre del bucket
  #   3. terraform init -migrate-state   (dice "yes" cuando pregunte)
  #   4. terraform plan -no-color > plan-3.txt
  #
  # Lo que pasa en el paso 3, que es lo que el profesor va a preguntar en la oral:
  # Terraform detecta que hay un estado local y uno remoto vacio, y ofrece COPIAR
  # el local al remoto. Si dices que no, empiezas con un estado vacio y el
  # siguiente plan querria crear otra vez todo lo que ya existe.
  #
  # backend "gcs" {
  #   bucket = "PON-AQUI-EL-NOMBRE-DEL-BUCKET"
  #   prefix = "terraform/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# ─── Tarea 2: las instancias que se importan ──────────────────────────────────
module "instances" {
  source = "./modules/instances"

  project_id = var.project_id
  zone       = var.zone
}

# ─── Tarea 3: el bucket del estado remoto ─────────────────────────────────────
module "storage" {
  source = "./modules/storage"

  project_id    = var.project_id
  region        = var.region
  nombre_bucket = var.nombre_bucket
}

# ─── Tarea 6: la red, con un modulo del Terraform Registry ────────────────────
# DESCOMENTAR en la tarea 6.
#
# La version va FIJA. El enunciado del laboratorio avisa de que no fijarla es uno
# de los errores tipicos, y tiene un motivo concreto: este modulo ha cambiado de
# mayor varias veces y entre una y otra se renombran variables. Si dejas la
# version suelta, el lab te funciona hoy y le falla a quien lo repita mañana.
#
# 18.3.1 es la ultima publicada al 04/11/2026. COMPRUEBA en el Registry si hay
# una mas nueva, y sobre todo si el enunciado del lab te pide una concreta: si
# pide una version, manda la del enunciado, no la mia.
#
# module "red" {
#   source  = "terraform-google-modules/network/google"
#   version = "18.3.1"
#
#   project_id   = var.project_id
#   network_name = var.network_name
#   routing_mode = "GLOBAL"
#
#   subnets = [
#     {
#       subnet_name   = "subnet-01"
#       subnet_ip     = "10.10.10.0/24"
#       subnet_region = var.region
#     },
#     {
#       subnet_name   = "subnet-02"
#       subnet_ip     = "10.10.20.0/24"
#       subnet_region = var.region
#     },
#   ]
# }

# ─── Tarea 7: la regla de firewall ────────────────────────────────────────────
# DESCOMENTAR en la tarea 7.
#
# Ojo con el cuarto error que avisa el enunciado: abrirla MAS de lo que pide.
# Lo que piden es http (tcp/80) desde cualquier origen hacia la red que creaste
# en la tarea 6. Nada mas. No agregues el 22, ni "all", ni rangos extra: cada
# puerto de sobra es una respuesta peor en la defensa oral.
#
# resource "google_compute_firewall" "tf_firewall" {
#   name    = "tf-firewall"
#   project = var.project_id
#
#   # La red del modulo, NO "default". Si apuntas a default, la tarea 7 no cuenta.
#   network = module.red.network_name
#
#   allow {
#     protocol = "tcp"
#     ports    = ["80"]
#   }
#
#   source_ranges = ["0.0.0.0/0"]
# }
