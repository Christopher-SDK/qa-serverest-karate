@usuarios @buscar
Feature: Buscar usuario por ID - GET /usuarios/{_id}
  Como administrador del sistema
  Quiero consultar un usuario específico por su ID
  Para ver sus datos

  Background:
    * url baseUrl

  @smoke @positivo
  Scenario: Buscar un usuario existente devuelve todos sus datos
    * def creado = crearUsuario()
    Given path 'usuarios', creado.id
    When method get
    Then status 200
    And match response == usuarioSchema
    # El esquema valida la forma; esta segunda validación confirma que los valores son los que envié.
    And match response == karate.merge(creado.usuario, { _id: creado.id })
    And assert responseTime < slaMs

  @negativo
  Scenario: Buscar un ID con formato válido que no existe devuelve 400
    # Según el Swagger de ServeRest, "no encontrado" responde 400 (no 404), así que valido eso.
    Given path 'usuarios', datos.idInexistente()
    When method get
    Then status 400
    And match response == { message: '#(msg.noEncontrado)' }

  @negativo
  Scenario Outline: Buscar con un ID de formato inválido (<caso>) devuelve 400
    Given path 'usuarios', '<id>'
    When method get
    Then status 400
    And match response == { id: '#(msg.idInvalido)' }

    Examples:
      | caso                      | id                 |
      | muy corto                 | abc123             |
      | 15 caracteres             | abcdefghijklmno    |
      | 17 caracteres             | abcdefghijklmnopq  |
      | con caracteres especiales | abcdefgh-jklmn_p   |
