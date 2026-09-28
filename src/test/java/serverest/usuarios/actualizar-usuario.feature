@usuarios @actualizar
Feature: Actualizar usuario - PUT /usuarios/{_id}
  Como administrador del sistema
  Quiero actualizar la información de un usuario existente
  Para mantener sus datos al día

  Background:
    * url baseUrl
    # Todos los escenarios parten de un usuario real ya creado, que es el que voy a modificar.
    * def creado = crearUsuario()
    * def id = creado.id

  @smoke @positivo
  Scenario: Actualizar todos los datos de un usuario existente
    * def cambios = datos.usuarioValido()
    Given path 'usuarios', id
    And request cambios
    When method put
    Then status 200
    And match response == { message: '#(msg.alterado)' }
    And assert responseTime < slaMs

    # Confirmo con un GET que el cambio realmente se guardó.
    Given path 'usuarios', id
    When method get
    Then status 200
    And match response == karate.merge(cambios, { _id: id })

  @positivo
  Scenario Outline: Actualizar solo el campo "<campo>" mantiene intactos los demás
    # PUT exige el body completo, así que copio el usuario original y cambio un único campo.
    * def cambios = karate.merge(creado.usuario, { <campo>: <nuevoValor> })
    Given path 'usuarios', id
    And request cambios
    When method put
    Then status 200
    And match response == { message: '#(msg.alterado)' }

    Given path 'usuarios', id
    When method get
    Then status 200
    And match response == karate.merge(cambios, { _id: id })

    Examples:
      | campo         | nuevoValor                                                     |
      | nome          | datos.nombre()                                                 |
      | email         | datos.emailUnico()                                             |
      | password      | datos.password()                                               |
      | administrador | creado.usuario.administrador == 'true' ? 'false' : 'true'      |

  @positivo
  Scenario: Hacer PUT sobre un ID que no existe crea un usuario nuevo
    # ServeRest documenta este comportamiento (tipo "upsert"): si el ID no existe, crea el usuario
    # y responde 201. Lo pruebo porque es fácil asumir que devolvería 404 o 400.
    * def nuevo = datos.usuarioValido()
    Given path 'usuarios', datos.idInexistente()
    And request nuevo
    When method put
    Then status 201
    And match response == registroSchema
    # La API ignora el ID de la URL y genera uno propio: guardo el que devuelve para limpiarlo.
    * def nuevoId = response._id
    * limpiarDespues(nuevoId)

    Given path 'usuarios', nuevoId
    When method get
    Then status 200
    And match response == karate.merge(nuevo, { _id: nuevoId })

  @negativo
  Scenario: No se puede cambiar el email por uno que ya usa otro usuario
    * def otro = crearUsuario()
    * def cambios = karate.merge(creado.usuario, { email: otro.usuario.email })
    Given path 'usuarios', id
    And request cambios
    When method put
    Then status 400
    And match response == { message: '#(msg.emailEnUso)' }

    # Y el usuario original no debe haber cambiado.
    Given path 'usuarios', id
    When method get
    Then match response.email == creado.usuario.email

  @negativo
  Scenario Outline: No se puede actualizar sin el campo obligatorio "<campo>"
    # copy (y no def) para trabajar sobre una copia y no modificar el usuario original.
    * copy cambios = creado.usuario
    * remove cambios.<campo>
    Given path 'usuarios', id
    And request cambios
    When method put
    Then status 400
    And match response == { <campo>: '<campo> é obrigatório' }

    Examples:
      | campo         |
      | nome          |
      | email         |
      | password      |
      | administrador |

  @negativo
  Scenario: No se puede actualizar con un email mal formado ni un perfil inválido
    * def cambios = karate.merge(creado.usuario, { email: 'correo-invalido', administrador: 'admin' })
    Given path 'usuarios', id
    And request cambios
    When method put
    Then status 400
    And match response == { email: '#(msg.emailInvalido)', administrador: '#(msg.adminInvalido)' }

  # HALLAZGO: GET y DELETE rechazan IDs que no tienen 16 caracteres alfanuméricos, pero PUT no
  # valida el ID y termina creando un usuario nuevo. Espero el mismo 400 que en GET. Excluido de
  # la ejecución normal con @hallazgo (ver README).
  @hallazgo @negativo
  Scenario: PUT con un ID de formato inválido debería rechazarse como en GET
    * def nuevo = datos.usuarioValido()
    Given path 'usuarios', 'abc'
    And request nuevo
    When method put
    * if (response._id) limpiarDespues(response._id)
    Then status 400
    And match response == { id: '#(msg.idInvalido)' }
