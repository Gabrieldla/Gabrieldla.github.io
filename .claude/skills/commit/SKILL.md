---
name: commit
description: Reglas de commit del curso IF-1116 (Tópicos de Tecnologías de Información)
---

# Reglas de commit

Al generar o revisar commits en este repositorio, sigue siempre estas reglas:

- **Un tema por commit.** Si un cambio toca dos asuntos distintos (por ejemplo,
  una sección nueva y un ajuste de estilo), divídelo en commits separados.
- **Mensaje en modo imperativo**, como una instrucción: "Agregar", "Corregir",
  "Actualizar" — nunca en pasado ("Agregué") ni gerundio ("Agregando").
- **Máximo 50 caracteres** en la primera línea del mensaje.
- **Sin punto final** en el mensaje.
- Antes de confirmar un commit generado por el agente, revisa `git diff --staged`
  y `git log --oneline` para verificar que cumple lo anterior. El último clic
  siempre es humano: corrige lo que no cumpla antes de aceptar.
- Los pull requests van a `main` siempre por rama (`feature/*`, `fix/*`,
  `docs/*`), nunca por push directo — `main` está protegida.
