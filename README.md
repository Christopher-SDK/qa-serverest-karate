# Automatización de la API de Usuarios de ServeRest — Karate DSL

[![CI](https://github.com/Christopher-SDK/qa-serverest-karate/actions/workflows/karate.yml/badge.svg)](https://github.com/Christopher-SDK/qa-serverest-karate/actions/workflows/karate.yml)

Suite de pruebas automatizadas para el recurso `/usuarios` de [ServeRest](https://serverest.dev/),
hecha con **Karate DSL** sobre Maven y JUnit 5.

Cubre las cinco operaciones del CRUD con casos positivos y negativos, validación de esquemas JSON
en cada respuesta, un generador de datos de prueba y limpieza automática de todo lo que la suite
crea en la API.

El informe con la estrategia y los patrones está en [`docs/INFORME.md`](docs/INFORME.md).

## Requisitos

- Java 17 o superior (lo probé con 17 y 23)
- Maven **no es obligatorio**: el repo trae el Maven Wrapper (`mvnw` / `mvnw.cmd`), que descarga
  la versión correcta la primera vez. Si ya tienes Maven instalado, puedes usar `mvn` en lugar de `./mvnw`.
- Opcional: Node.js 18+, solo si quieres correr las pruebas contra un ServeRest local

## Instalación

```bash
git clone https://github.com/Christopher-SDK/qa-serverest-karate.git
cd qa-serverest-karate
./mvnw -q test-compile    # descarga dependencias y compila; no ejecuta pruebas
```

## Cómo ejecutar

| Qué quiero hacer                                   | Comando |
|----------------------------------------------------|---------|
| Toda la suite contra https://serverest.dev         | `./mvnw test` |
| Solo los escenarios críticos                       | `./mvnw test -Dkarate.options="--tags @smoke"` |
| Solo un endpoint                                   | `./mvnw test -Dkarate.options="--tags @registrar"` |
| Solo casos negativos de un endpoint                | `./mvnw test -Dkarate.options="--tags @actualizar --tags @negativo"` |
| Un solo feature                                    | `./mvnw test -Dkarate.options="classpath:serverest/usuarios/buscar-usuario.feature"` |
| Contra un ServeRest local                          | `./mvnw test -Dkarate.env=local` (ver abajo) |
| Contra otra URL                                    | `./mvnw test -DbaseUrl=http://mi-servidor:3000` |
| Cambiar hilos en paralelo (por defecto 5)          | `./mvnw test -Dthreads=1` |
| Ver los hallazgos (defectos encontrados)           | `./mvnw test -Dkarate.options="--tags @hallazgo"` |

> En Karate, varios `--tags` seguidos funcionan como **Y** (AND), y separados por coma dentro
> del mismo `--tags` funcionan como **O** (OR): `--tags @listar,@buscar`.

### En Windows

Usa `mvnw.cmd` en lugar de `./mvnw`. En **PowerShell** además hay que poner cada `-D...` entre
comillas completas, porque PowerShell corta el argumento en el punto:

```powershell
.\mvnw.cmd test
.\mvnw.cmd test "-Dkarate.options=--tags @smoke"
.\mvnw.cmd test "-Dkarate.env=local"
```

En `cmd.exe` funcionan igual que en el resto de la tabla, cambiando `./mvnw` por `mvnw.cmd`.

### Correr contra un ServeRest local

La API pública la usa mucha gente al mismo tiempo. Para no depender de eso (ni llenarla de datos),
se puede levantar ServeRest en la propia máquina:

```bash
npx serverest@latest              # en una terminal (queda escuchando en http://localhost:3000)
./mvnw test -Dkarate.env=local    # en otra
```

### Tags

| Tag | Significado |
|-----|-------------|
| `@listar` `@registrar` `@buscar` `@actualizar` `@eliminar` | Endpoint que se prueba |
| `@positivo` / `@negativo` | Tipo de caso |
| `@smoke` | Lo mínimo para saber que la API funciona; también valida tiempo de respuesta |
| `@e2e` | Ciclo de vida completo de un usuario |
| `@regla-negocio` | No se puede borrar un usuario con carrito |
| `@hallazgo` | Documenta un defecto encontrado. **Excluido por defecto** porque falla a propósito |
| `@ignore` | Features reutilizables (no son pruebas por sí mismos) |

## Reportes

Después de ejecutar, abre **`target/karate-reports/karate-summary.html`** en el navegador. Ahí se
ve cada feature y escenario con sus pasos, y para cada request el método, URL, body, headers y la
respuesta completa. También se generan:

- `target/karate-reports/karate-timeline.html` — cómo se repartieron los escenarios entre los hilos.
- `target/karate-reports/*.json` (formato Cucumber) y `target/karate-reports/*.xml` (JUnit) para CI.
- `target/karate.log` — log completo de requests y responses.

## Estructura del proyecto

```
src/test/java/
  karate-config.js                 Configuración global: ambientes, esquemas, mensajes, limpieza
  logback-test.xml                 Logs (consola resumida, detalle en target/karate.log)
  serverest/
    ServeRestTest.java             Runner paralelo (JUnit 5)
    usuarios/                      Un feature por endpoint
      listar-usuarios.feature      GET    /usuarios
      registrar-usuario.feature    POST   /usuarios
      buscar-usuario.feature       GET    /usuarios/{_id}
      actualizar-usuario.feature   PUT    /usuarios/{_id}
      eliminar-usuario.feature     DELETE /usuarios/{_id}
      ciclo-de-vida.feature        Flujo completo encadenando los 5 endpoints
    schemas/                       Esquemas JSON de las respuestas
      usuario.json
      lista-usuarios.json
      registro-exitoso.json
    common/                        Piezas reutilizables
      crear-usuario.feature        Crea un usuario como precondición
      eliminar-usuario.feature     Borra un usuario (limpieza)
      mensajes.json                Mensajes de la API en un solo lugar
    helpers/
      UsuarioDataFactory.java      Generador de datos de prueba (Datafaker)
      UsuarioDataFactoryTest.java  Pruebas unitarias del generador
.github/workflows/karate.yml       Pipeline de GitHub Actions
docs/INFORME.md                    Estrategia y patrones
```

## Cobertura

| Endpoint | Positivos | Negativos | Qué valido |
|----------|:--:|:--:|------------|
| `GET /usuarios` | 7 | 5 | Esquema de la lista, que `quantidade` coincida con el arreglo, filtros por email, `_id` y administrador, filtros combinados, resultados vacíos, valores y parámetros inválidos |
| `POST /usuarios` | 2 | 21 | Registro con cada perfil y verificación con GET; email duplicado; cada campo faltante, vacío o con tipo incorrecto; 6 formatos de email inválidos; valores inválidos de administrador; campos no permitidos; body vacío |
| `GET /usuarios/{_id}` | 1 | 5 | Esquema y valores; ID inexistente; 4 formatos de ID inválidos |
| `PUT /usuarios/{_id}` | 6 | 6 | Actualización total y campo por campo (verificando con GET); creación cuando el ID no existe; email ya usado por otro usuario; campos faltantes; formato inválido |
| `DELETE /usuarios/{_id}` | 1 | 3 | Eliminación y verificación; ID inexistente; doble eliminación; usuario con carrito |
| Ciclo de vida | 1 | — | POST → GET → GET con filtro → PUT → GET → DELETE → GET |

**58 escenarios** en la ejecución normal (todos en verde contra `serverest.dev` y contra ServeRest
local) + **2 escenarios `@hallazgo`** que documentan defectos.

## Hallazgos

Mientras exploraba la API encontré dos comportamientos que considero defectos. No los dejé pasar
en silencio ni los hice "pasar" ajustando la prueba: escribí el escenario con el comportamiento
esperado y lo marqué con `@hallazgo`, que está excluido de la ejecución normal para no romper el
pipeline. Si algún día se corrigen, basta con quitar el tag.

1. **El email distingue mayúsculas.** Si existe `ana@correo.com`, la API deja registrar
   `ANA@CORREO.COM` como un usuario distinto. (`registrar-usuario.feature`)
2. **PUT no valida el formato del ID.** `GET` y `DELETE` responden 400 si el ID no tiene 16
   caracteres alfanuméricos, pero `PUT /usuarios/abc` crea un usuario nuevo con 201.
   (`actualizar-usuario.feature`)

También dejé documentados en las pruebas dos comportamientos que no son defectos pero sorprenden:
"usuario no encontrado" responde **400** y no 404 (así está en el Swagger), y `PUT` sobre un ID
inexistente **crea** el usuario (upsert).

## Qué agregué además de lo pedido (y por qué)

- **Limpieza automática de datos.** Todo usuario que crea un escenario se borra al final, aunque el
  escenario falle a la mitad. La API es pública y compartida; no quiero dejar basura ni que una
  ejecución fallida afecte a la siguiente.
- **Dos ambientes (`prod` y `local`)** configurables por parámetro, y un pipeline de CI que usa el
  local para decidir si el build pasa, así un problema de red del sitio público no rompe el build.
- **Caso de regla de negocio**: no se puede eliminar un usuario con carrito. Es el único 400 que
  documenta el Swagger para DELETE y requiere armar login, producto y carrito desde cero.
- **Escenario de ciclo de vida** que encadena los 5 endpoints como los usaría un administrador.
- **Validación de tiempo de respuesta** en los escenarios `@smoke` (umbral configurable con `-DslaMs`).
- **Pruebas unitarias del generador de datos**, para que un error ahí se detecte antes de que
  falle toda la suite.
- **Hallazgos documentados** como pruebas ejecutables (ver sección anterior).
- **Pipeline de GitHub Actions** en cada push, PR y una vez al día, con los reportes descargables.

## Problemas comunes

- `Unsupported class file major version` o errores al compilar → estás usando Java < 17. Revisa con `java -version`.
- Fallos intermitentes por timeout contra `serverest.dev` → la API pública tiene picos. Prueba con
  menos hilos (`-Dthreads=2`) o contra el ServeRest local.
