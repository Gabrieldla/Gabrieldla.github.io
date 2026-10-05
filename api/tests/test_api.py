"""Pruebas de la API del libro de visitas.

Todas corren SIN base de datos, a propósito: el job `test` del pipeline no levanta
Postgres. Se apoyan en que la validación del cuerpo ocurre antes de abrir cualquier
conexión, y en que /api/health está hecho para responder 503 cuando no alcanza la base.
Las pruebas que sí necesitan la aplicación completa están en el job de integración,
que levanta los tres servicios con Compose.
"""
import json

import psycopg
import pytest

from app import app


@pytest.fixture
def cliente():
    app.config.update(TESTING=True)
    return app.test_client()


def publicar(cliente, cuerpo):
    return cliente.post(
        "/api/mensajes",
        data=json.dumps(cuerpo),
        content_type="application/json",
    )


class TestHealth:
    def test_sin_base_de_datos_responde_503(self, cliente):
        # "Estoy vivo" no alcanza: si no puede hablar con la base, no está sano.
        r = cliente.get("/api/health")
        assert r.status_code == 503
        assert r.get_json()["status"] == "error"


class TestValidacionDeMensajes:
    def test_falta_el_nombre(self, cliente):
        r = publicar(cliente, {"mensaje": "Hola"})
        assert r.status_code == 400
        assert "error" in r.get_json()

    def test_falta_el_mensaje(self, cliente):
        r = publicar(cliente, {"nombre": "Gabriel"})
        assert r.status_code == 400

    def test_campos_en_blanco(self, cliente):
        # Un espacio no es un nombre: la API hace trim antes de validar.
        r = publicar(cliente, {"nombre": "   ", "mensaje": "   "})
        assert r.status_code == 400

    def test_mensaje_demasiado_largo(self, cliente):
        r = publicar(cliente, {"nombre": "Gabriel", "mensaje": "a" * 281})
        assert r.status_code == 400
        assert "280" in r.get_json()["error"]

    def test_nombre_demasiado_largo(self, cliente):
        r = publicar(cliente, {"nombre": "a" * 61, "mensaje": "Hola"})
        assert r.status_code == 400
        assert "60" in r.get_json()["error"]

    def test_cuerpo_que_no_es_json(self, cliente):
        r = cliente.post("/api/mensajes", data="esto no es json", content_type="text/plain")
        assert r.status_code == 400

    def test_el_limite_exacto_de_280_es_valido(self, cliente):
        # 280 caracteres es válido; 281 no. Esta prueba fija la frontera.
        # Sin base de datos la petición no puede terminar, y eso es justamente la
        # prueba: si falla al CONECTAR y no con un 400, es que pasó la validación.
        with pytest.raises(psycopg.OperationalError):
            publicar(cliente, {"nombre": "Gabriel", "mensaje": "a" * 280})


class TestRutas:
    def test_una_ruta_que_no_existe_da_404(self, cliente):
        assert cliente.get("/api/no-existe").status_code == 404

    def test_el_metodo_equivocado_da_405(self, cliente):
        assert cliente.delete("/api/mensajes").status_code == 405
