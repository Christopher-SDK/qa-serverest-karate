# Informe: estrategia de automatización y patrones — API de Usuarios de ServeRest

## 1. Cómo arranqué

Antes de escribir una sola prueba revisé el Swagger de ServeRest y después golpeé cada endpoint a
mano con curl para ver qué responde realmente: códigos de estado, mensajes exactos, qué valida y
qué no. Esto me sirvió para tres cosas:

- Conocer los mensajes exactos (están en portugués) y los códigos reales. Por ejemplo, "usuario no
  encontrado" responde **400**, no 404, y un `PUT` sobre un ID inexistente **crea** el usuario.
- Descubrir que la API valida todos los campos a la vez y devuelve un objeto con un error por campo.
  Eso me permitió comparar la respuesta completa con `==` y confirmar que la API se queja *solo*
  del campo que rompí.
- Encontrar dos defectos (sección 6).

## 2. Organización

Hice **un feature por endpoint**, como pide el reto, más un feature de ciclo de vida que los
encadena. Cada feature arranca con la historia de usuario en formato Como/Quiero/Para y sus
escenarios están etiquetados por endpoint, tipo de caso (`@positivo`/`@negativo`) y criticidad
(`@smoke`), para poder correr cualquier combinación sin tocar código.

Lo que se comparte entre features lo saqué a su lugar:

| Qué | Dónde | Por qué |
|-----|-------|---------|
| URL por ambiente, timeouts, SLA | `karate-config.js` | Cambiar de ambiente es un parámetro (`-Dkarate.env`), no una edición |
| Esquemas de respuesta | `schemas/*.json` | Se definen una vez y se usan en todos los features |
| Mensajes de la API | `common/mensajes.json` | Si la API cambia un texto, se corrige en un solo archivo |
| Datos de prueba | `helpers/UsuarioDataFactory.java` | Un solo generador, con pruebas unitarias propias |
| Crear / borrar usuario | `common/*.feature` + `crearUsuario()` | Preparar precondiciones en una línea |

## 3. Patrones que usé

**Features reutilizables (equivalente a Page Object, pero para API).** `crear-usuario.feature` y
`eliminar-usuario.feature` están marcados con `@ignore` y se llaman desde otros escenarios. Encima
de ellos dejé una función `crearUsuario()` en `karate-config.js`, así un escenario que necesita un
usuario existente como precondición lo resuelve con `* def creado = crearUsuario()`.

**Data Factory.** `UsuarioDataFactory` genera usuarios válidos con Datafaker. La regla principal es
que el email siempre es único (prefijo reconocible + parte de un UUID), porque la API pública es
compartida y un email fijo chocaría con datos de otras personas o de ejecuciones anteriores.
También genera IDs con formato válido pero inexistentes, que necesito para probar "no encontrado"
sin que la API corte antes por formato inválido.

**"Partir de algo válido y romper una sola cosa".** En los negativos parto siempre de un usuario
válido y modifico solo el campo bajo prueba (`remove`, `set`). Si la prueba falla, sé que es por
ese campo. Con Scenario Outline cubro todos los campos sin repetir escenarios.

**Arrange / Act / Assert con verificación posterior.** En las operaciones que modifican datos
(POST, PUT, DELETE) no me quedo con el código de estado: hago un GET después para confirmar que el
cambio se guardó (o que el usuario ya no existe). Un 200 sin el efecto esperado también es un bug.

**Limpieza en `afterScenario`.** Cada usuario que se crea se registra para la limpieza y se borra en
el hook `afterScenario`, que corre aunque el escenario falle. Si la limpieza estuviera como último
paso del escenario, una aserción fallida a la mitad dejaría el usuario huérfano. El registro se hace
con `limpiarSiSeCreo()` justo después de cada POST o PUT a `/usuarios`, **antes** de validar nada:
si la respuesta trae un `_id`, se creó un usuario y queda anotado. Así tampoco queda basura si una
validación falla antes de tiempo, o si algún día la API acepta por error los datos de un caso
negativo.
El escenario del usuario con carrito también registra el producto y el carrito que crea
(`limpiarProductoDespues`, `limpiarCarritoDespues`), y el hook los limpia en el orden que exige la
API: primero cancela el carrito, después borra el producto y al final el usuario. Si no, un fallo a
la mitad dejaría los tres en la API, porque no se puede borrar un usuario que tiene carrito. Lo
comprobé forzando un fallo justo después de crear el carrito: la API quedó igual que antes.
Después de varias ejecuciones verifiqué contra la API que no quedaba ningún usuario de la suite.

## 4. Validación de esquemas

Uso la validación nativa de Karate (`match ... == esquema`) con marcadores como `#string`,
`#regex` y `#[]`. La elegí sobre JSON Schema estándar porque:

- no necesita dependencias extra ni código Java adicional;
- con `==` es estricta: falla si falta un campo **o si aparece uno que no esperaba**;
- se lee casi como la respuesta misma, así que cualquiera entiende qué se está validando.

Los esquemas validan formato real y no solo tipo: el `_id` debe tener 16 caracteres alfanuméricos,
`administrador` solo puede ser `"true"` o `"false"`, y el email debe tener forma de email. Para la
lista hay un matiz: en la API pública la lista completa trae usuarios que crearon otras personas y
que yo no controlo. Si les exigiera el formato estricto, la suite podría fallar por datos ajenos.
Por eso la lista completa se valida con `usuario-en-lista.json` (que estén todos los campos, con su
tipo, y ninguno de más) y compruebo que `quantidade` coincida con el largo real del arreglo. El
formato estricto de `usuario.json` lo aplico a los usuarios que crea la propia suite, incluidos los
que devuelven los filtros de la lista.

Para comprobar que los esquemas no pasan "por accidente", rompí uno a propósito (cambié `nome` a
`#number`) y confirmé que la prueba fallaba señalando exactamente el campo.

Además del esquema, en los positivos comparo los **valores**: lo que devuelve el GET tiene que
ser exactamente lo que envié más el `_id` generado.

## 5. Datos y ambientes

- **Prod** (`https://serverest.dev`, por defecto) y **local** (`npx serverest`, con
  `-Dkarate.env=local`). La suite pasa completa en los dos.
- En CI el ambiente local es el que decide si el build pasa; el de prod corre en paralelo para
  enterarme si la API pública cambió, pero está marcado con `continue-on-error`, así que una caída
  o un problema de red del sitio público queda a la vista sin poner el pipeline en rojo.
- El tiempo de respuesta de los `@smoke` (3000 ms, configurable) se exige en local. Contra la API
  pública solo queda como advertencia en el reporte, porque ahí mide sobre todo la red.
- La suite corre en paralelo (5 hilos por defecto). Es seguro porque ningún escenario depende de
  datos de otro: cada uno crea lo que necesita.

## 6. Hallazgos

| # | Hallazgo | Esperado | Actual |
|---|----------|----------|--------|
| 1 | El email distingue mayúsculas | `ANA@x.com` debería considerarse el mismo que `ana@x.com` → 400 | 201, crea un usuario duplicado |
| 2 | PUT no valida el formato del ID | `PUT /usuarios/abc` debería responder 400 como GET y DELETE | 201, crea un usuario |

Ambos están escritos como escenarios con el comportamiento esperado y el tag `@hallazgo`. Están
excluidos de la ejecución normal (fallarían a propósito) y se corren con
`mvn test -Dkarate.options="--tags @hallazgo"`.

## 7. Resultados

- 58 escenarios en verde contra `serverest.dev` y contra ServeRest local.
- 2 escenarios `@hallazgo` que reproducen los defectos.
- 3 pruebas unitarias del generador de datos.
- Tiempo aproximado: unos 15 s de pruebas contra la API pública y unos pocos segundos contra la local (más el arranque de Maven).

## 8. Siguientes pasos que propondría

- Extender el mismo enfoque a `/login`, `/produtos` y `/carrinhos`, reutilizando el generador y
  la limpieza.
- Validar las respuestas contra el `swagger.json` publicado, para detectar cuando la
  implementación se aleje de la documentación.
- Pruebas de carga ligeras reutilizando estos mismos features con Gatling (Karate lo permite).
