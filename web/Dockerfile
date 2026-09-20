# Contexto de build = raíz del repo (ver compose.yaml), para poder copiar index.html,
# que tiene que seguir en la raíz porque GitHub Pages lo sirve desde ahí.
FROM nginxinc/nginx-unprivileged:1.31.6-alpine3.24

# Primero la config (cambia poco) y después el contenido (cambia más): mejor caché.
# --chmod=644: solo lectura; los archivos vienen de Windows con permiso de ejecución.
COPY --chmod=644 web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --chmod=644 index.html libro-de-visitas.js estilos.css /usr/share/nginx/html/

EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["curl", "-fsS", "-o", "/dev/null", "http://127.0.0.1:8080/healthz"]
