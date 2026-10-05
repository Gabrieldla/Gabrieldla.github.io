import { describe, it, expect, beforeAll } from 'vitest'
import { readFileSync, existsSync } from 'node:fs'
import { JSDOM } from 'jsdom'

// Se prueba la carpeta que arma scripts/armar-sitio.sh, que es exactamente la que
// se publica en GitHub Pages. Probar el repositorio en vez de _site/ sería probar
// una cosa y publicar otra.
const SITIO = '_site'
let doc, html

beforeAll(() => {
  html = readFileSync(`${SITIO}/index.html`, 'utf-8')
  doc = new JSDOM(html).window.document
})

describe('index.html', () => {
  it('tiene un título', () => {
    expect(doc.title.trim()).not.toBe('')
  })

  it('muestra mi nombre en el h1', () => {
    expect(doc.querySelector('h1')?.textContent).toContain('Gabriel De la Rivera')
  })

  it('todas las imágenes tienen texto alternativo', () => {
    const sinAlt = [...doc.querySelectorAll('img')].filter((img) => !img.getAttribute('alt'))
    expect(sinAlt).toHaveLength(0)
  })

  it('los archivos locales que usa la página existen', () => {
    const rutas = [...doc.querySelectorAll('script[src], link[rel="stylesheet"], img[src]')]
      .map((el) => el.getAttribute('src') ?? el.getAttribute('href'))
      .filter((ruta) => !/^(https?:)?\/\//.test(ruta))
    for (const ruta of rutas) {
      expect(existsSync(`${SITIO}/${ruta}`), `falta ${ruta}`).toBe(true)
    }
  })
})

describe('el sitio que se publica', () => {
  it('no incluye archivos internos del repositorio', () => {
    for (const interno of ['compose.yaml', '.env.example', 'api', 'db', 'tests']) {
      expect(existsSync(`${SITIO}/${interno}`), `${interno} no debería publicarse`).toBe(false)
    }
  })
})

// ───────────────────────── pruebas propias ─────────────────────────

describe('accesibilidad y metadatos', () => {
  it('declara el idioma, el charset y el viewport', () => {
    expect(doc.documentElement.getAttribute('lang')).toBe('es')
    expect(doc.querySelector('meta[charset]')).not.toBeNull()
    expect(doc.querySelector('meta[name="viewport"]')).not.toBeNull()
  })

  it('tiene un solo h1 y los títulos no saltan de nivel', () => {
    expect(doc.querySelectorAll('h1')).toHaveLength(1)
    const niveles = [...doc.querySelectorAll('h1, h2, h3, h4, h5, h6')]
      .map((h) => Number(h.tagName[1]))
    for (let i = 1; i < niveles.length; i++) {
      // Bajar de h2 a h4 deja un hueco que rompe la navegación por lector de pantalla.
      expect(niveles[i] - niveles[i - 1], `salto de h${niveles[i - 1]} a h${niveles[i]}`)
        .toBeLessThanOrEqual(1)
    }
  })
})

describe('seguridad de los enlaces', () => {
  it('los enlaces externos se abren aparte y con rel="noopener"', () => {
    const externos = [...doc.querySelectorAll('a[href^="http"]')]
    expect(externos.length).toBeGreaterThan(0)
    for (const a of externos) {
      const href = a.getAttribute('href')
      expect(a.getAttribute('target'), `${href} sin target`).toBe('_blank')
      // Sin noopener, la página destino puede manipular la pestaña de origen.
      expect(a.getAttribute('rel') ?? '', `${href} sin rel=noopener`).toContain('noopener')
    }
  })

  it('no quedan rutas de mi máquina ni localhost', () => {
    expect(html).not.toMatch(/localhost|127\.0\.0\.1|file:\/\/|C:\\/i)
  })
})

describe('libro de visitas', () => {
  it('arranca oculto, para que GitHub Pages no muestre una sección rota', () => {
    // En Pages no existe /api: si la sección no arrancara oculta, se vería vacía.
    const seccion = doc.querySelector('#libro-de-visitas')
    expect(seccion).not.toBeNull()
    expect(seccion.hasAttribute('hidden')).toBe(true)
  })

  it('el formulario tiene los campos que espera la API', () => {
    const form = doc.querySelector('#form-mensaje')
    expect(form).not.toBeNull()
    expect(form.querySelector('[name="nombre"]')).not.toBeNull()
    expect(form.querySelector('[name="mensaje"]')).not.toBeNull()
    // La API rechaza con 400 lo que pase de 280 caracteres: el formulario avisa antes.
    expect(form.querySelector('[name="mensaje"]').getAttribute('maxlength')).toBe('280')
  })

  it('carga el JavaScript que habla con la API', () => {
    expect(doc.querySelector('script[src="libro-de-visitas.js"]')).not.toBeNull()
  })
})

describe('contacto', () => {
  it('el correo publicado es el institucional', () => {
    const correo = doc.querySelector('a[href^="mailto:"]')?.getAttribute('href')
    expect(correo).toMatch(/@urp\.edu\.pe$/)
  })
})
