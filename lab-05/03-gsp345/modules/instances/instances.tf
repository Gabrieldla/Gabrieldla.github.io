# Las dos instancias de la tarea 2 YA EXISTEN: el lab las crea a mano antes de que
# empieces. Aqui no se crean, se IMPORTAN, y eso cambia como hay que escribir este
# archivo.
#
# ─────────────────────────────────────────────────────────────────────────────
# LEE ESTO ANTES DE TOCAR NADA
# ─────────────────────────────────────────────────────────────────────────────
# El criterio del profesor para la tarea 2 es que `plan-2.txt`, el de DESPUES de
# importar, diga "No changes". Si dice que va a destruir y recrear las instancias,
# la tarea no suma aunque Google te haya dado los puntos.
#
# Por eso el orden correcto NO es "escribo el .tf y luego importo". Es al reves:
#
#   1. Dejas estos dos bloques como estan (minimos, con los valores que veas en la
#      consola de Google: Compute Engine -> VM instances).
#   2. terraform import module.instances.google_compute_instance.tf_instance_1 \
#        <project>/<zona>/tf-instance-1
#   3. terraform show -no-color > show-tras-import.txt
#   4. ABRES ese archivo y copias de ahi los valores reales a estos bloques:
#      machine_type, la imagen del boot_disk y el network_interface.
#   5. terraform plan -no-color > plan-2.txt  ->  tiene que decir "No changes"
#
# Adivinar los atributos es exactamente el error que el enunciado avisa que comete
# la IA. El estado importado es la unica fuente de verdad: lo que diga
# `terraform show` es lo que hay, no lo que yo crea que hay.

resource "google_compute_instance" "tf_instance_1" {
  name         = "tf-instance-1"
  project      = var.project_id
  zone         = var.zone
  machine_type = "e2-micro" # <-- COMPROBAR en show-tras-import.txt

  boot_disk {
    initialize_params {
      # <-- COMPROBAR: suele ser una imagen de Debian, pero copia la exacta
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "default"
  }

  # Sin esto, cambiar machine_type en la tarea 4 falla: Terraform no puede
  # redimensionar una instancia encendida y aborta en vez de apagarla.
  allow_stopping_for_update = true
}

resource "google_compute_instance" "tf_instance_2" {
  name         = "tf-instance-2"
  project      = var.project_id
  zone         = var.zone
  machine_type = "e2-micro" # <-- COMPROBAR en show-tras-import.txt

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12" # <-- COMPROBAR
    }
  }

  network_interface {
    network = "default"
  }

  allow_stopping_for_update = true
}

# ─── Tarea 4: la instancia nueva ─────────────────────────────────────────────
# Esta SI se crea de cero. El enunciado del lab te dice el nombre exacto (suele
# ser tf-instance-3) y a que red tiene que ir: la del modulo del Registry de la
# tarea 6, NO la default. Si la cuelgas de "default", la tarea 6 no cuenta.
#
# Descomentala cuando llegues a la tarea 4.
#
# resource "google_compute_instance" "tf_instance_3" {
#   name         = "tf-instance-3"
#   project      = var.project_id
#   zone         = var.zone
#   machine_type = "e2-standard-2"
#
#   boot_disk {
#     initialize_params {
#       image = "debian-cloud/debian-12"
#     }
#   }
#
#   network_interface {
#     network    = var.network_name
#     subnetwork = var.subnetwork_name
#   }
#
#   allow_stopping_for_update = true
# }
#
# Y en la tarea 5 la borras: quitas el bloque y aplicas. No uses
# `terraform destroy -target`, porque eso destruye sin dejar rastro en el codigo
# y el .tf que entregas dejaria de corresponder al estado.
