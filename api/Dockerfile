# Versión ingenua: funciona, pero es enorme y corre como root.
# Se mejora en el Reto 1 (multi-stage) y el Reto 3 (usuario sin privilegios).
FROM python:3.12.14-trixie

WORKDIR /app
COPY . .
RUN pip install -r requirements.txt

EXPOSE 3000
CMD ["gunicorn", "-b", "0.0.0.0:3000", "app:app"]
