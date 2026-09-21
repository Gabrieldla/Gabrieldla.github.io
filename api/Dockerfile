# ── Etapa 1: build ─────────────────────────────────────────────────────────────
# Instala las dependencias en un entorno virtual aislado (/opt/venv).
FROM python:3.12.14-alpine3.24 AS build

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1
RUN python -m venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH

# Solo requirements.txt: esta capa (la lenta) se reutiliza mientras no cambien las dependencias.
COPY requirements.txt .
# pip se usa para instalar y después se quita del venv: no debe viajar a la imagen final.
RUN pip install -r requirements.txt \
 && pip uninstall -y pip

# ── Etapa 2: imagen final ──────────────────────────────────────────────────────
# Misma base que la etapa build, así el venv (que apunta a /usr/local/bin/python) funciona.
# Alpine en vez de slim-Debian: 99 MB en vez de 206 y 0 CVE críticas/altas (Reto 5).
# De la etapa anterior solo se trae el venv: nada de caché de pip ni archivos temporales.
FROM python:3.12.14-alpine3.24

ENV PATH=/opt/venv/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Usuario sin privilegios: si alguien escapa del proceso, no es root dentro del contenedor.
# En Alpine se crea con adduser (BusyBox), no con useradd: -S sistema, -D sin contraseña,
# -H sin home. Los archivos siguen siendo de root y este usuario solo puede leerlos.
RUN adduser -S -D -H -u 10001 app

WORKDIR /app
COPY --from=build /opt/venv /opt/venv
COPY app.py .

USER app

EXPOSE 3000
# La imagen no tiene curl ni wget: el chequeo usa urllib de la librería estándar.
# /api/health responde 503 si no alcanza la base, y urlopen lanza error con un 503.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:3000/api/health', timeout=2)"]
CMD ["gunicorn", "-b", "0.0.0.0:3000", "app:app"]
