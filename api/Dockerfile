# ── Etapa 1: build ─────────────────────────────────────────────────────────────
# Instala las dependencias en un entorno virtual aislado (/opt/venv).
FROM python:3.12.14-slim-trixie AS build

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
# De la etapa anterior solo se trae el venv: nada de caché de pip ni archivos temporales.
FROM python:3.12.14-slim-trixie

ENV PATH=/opt/venv/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY --from=build /opt/venv /opt/venv
COPY app.py .

EXPOSE 3000
CMD ["gunicorn", "-b", "0.0.0.0:3000", "app:app"]
