@usuarios @e2e
Feature: Ciclo de vida completo de un usuario
  # Los otros features prueban cada endpoint por separado. Este los encadena en el orden en que
  # los usaría un administrador real, para comprobar que funcionan bien juntos.

  Background:
    * url baseUrl

  @smoke @positivo
  Scenario: Registrar, consultar, listar, actualizar y eliminar un mismo usuario
    * def usuario = datos.usuarioValido(false)

    # 1. Registrar
    Given path 'usuarios'
    And request usuario
    When method post
    * limpiarSiSeCreo()
    Then status 201
    And match response == registroSchema
    * def id = response._id

    # 2. Buscar por ID
    Given path 'usuarios', id
    When method get
    Then status 200
    And match response == karate.merge(usuario, { _id: id })

    # 3. Aparece en la lista filtrando por su email
    Given path 'usuarios'
    And param email = usuario.email
    When method get
    Then status 200
    And match response.quantidade == 1
    And match response.usuarios[0]._id == id

    # 4. Lo promuevo a administrador
    * def actualizado = karate.merge(usuario, { administrador: 'true' })
    Given path 'usuarios', id
    And request actualizado
    When method put
    * limpiarSiSeCreo()
    Then status 200
    And match response.message == msg.alterado

    Given path 'usuarios', id
    When method get
    Then status 200
    And match response.administrador == 'true'

    # 5. Eliminar
    Given path 'usuarios', id
    When method delete
    Then status 200
    And match response.message == msg.eliminado

    # 6. Ya no existe
    Given path 'usuarios', id
    When method get
    Then status 400
    And match response.message == msg.noEncontrado
