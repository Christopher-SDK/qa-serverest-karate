@usuarios @registrar
Feature: Registrar usuario - POST /usuarios
  Como administrador del sistema
  Quiero registrar usuarios nuevos
  Para que puedan usar la tienda

  Background:
    * url baseUrl
    # Cada escenario parte de un usuario válido recién generado. En los negativos solo le
    # rompo el campo que quiero probar; así, si falla, sé que fue por ese campo y no por otro.
    * def usuario = datos.usuarioValido()

  @smoke @positivo
  Scenario Outline: Registrar un usuario válido con administrador=<admin>
    * set usuario.administrador = '<admin>'
    Given path 'usuarios'
    And request usuario
    When method post
    Then status 201
    And match response == registroSchema
    And assert responseTime < slaMs
    * def id = response._id
    * limpiarDespues(id)

    # No me quedo con el 201: consulto el usuario para confirmar que se guardó con los mismos datos.
    Given path 'usuarios', id
    When method get
    Then status 200
    And match response == karate.merge(usuario, { _id: id })

    Examples:
      | admin |
      | true  |
      | false |

  @negativo
  Scenario: No se puede registrar un email que ya está en uso
    * def existente = crearUsuario()
    * set usuario.email = existente.usuario.email
    Given path 'usuarios'
    And request usuario
    When method post
    Then status 400
    And match response == { message: '#(msg.emailEnUso)' }

  @negativo
  Scenario Outline: No se puede registrar un usuario sin el campo obligatorio "<campo>"
    * remove usuario.<campo>
    Given path 'usuarios'
    And request usuario
    When method post
    Then status 400
    # Comparo con == (igualdad exacta) para comprobar además que la API se queja SOLO del campo que falta.
    And match response == { <campo>: '<campo> é obrigatório' }

    Examples:
      | campo         |
      | nome          |
      | email         |
      | password      |
      | administrador |

  @negativo
  Scenario Outline: No se puede registrar un usuario con "<campo>" en blanco
    * set usuario.<campo> = ''
    Given path 'usuarios'
    And request usuario
    When method post
    Then status 400
    # Comillas dobles porque el mensaje de "administrador" trae comillas simples adentro.
    And match response == { <campo>: "<mensaje>" }

    Examples:
      | campo         | mensaje                                   |
      | nome          | nome não pode ficar em branco             |
      | email         | email não pode ficar em branco            |
      | password      | password não pode ficar em branco         |
      | administrador | administrador deve ser 'true' ou 'false'  |

  @negativo
  Scenario Outline: No se puede registrar un usuario con un email mal formado: <email>
    * set usuario.email = '<email>'
    Given path 'usuarios'
    And request usuario
    When method post
    Then status 400
    And match response == { email: '#(msg.emailInvalido)' }

    Examples:
      | email                 |
      | sin-arroba.com        |
      | usuario@              |
      | @dominio.com          |
      | usuario@dominio       |
      | con espacio@dominio.com |
      | usuario@dominio.c     |

  @negativo
  Scenario Outline: No se puede registrar un usuario con administrador=<valor>
    * set usuario.administrador = '<valor>'
    Given path 'usuarios'
    And request usuario
    When method post
    Then status 400
    And match response == { administrador: '#(msg.adminInvalido)' }

    Examples:
      | valor |
      | si    |
      | TRUE  |
      | 1     |

  @negativo
  Scenario: No se puede registrar un usuario con tipos de dato incorrectos
    # Aquí sí armo el body a mano: quiero números y booleanos reales en vez de strings.
    Given path 'usuarios'
    And request { nome: 123, email: '#(usuario.email)', password: 456, administrador: true }
    When method post
    Then status 400
    And match response ==
      """
      {
        nome: 'nome deve ser uma string',
        password: 'password deve ser uma string',
        administrador: '#(msg.adminInvalido)'
      }
      """

  @negativo
  Scenario: No se puede registrar un usuario con un campo que la API no conoce
    * set usuario.telefono = '999888777'
    Given path 'usuarios'
    And request usuario
    When method post
    Then status 400
    And match response == { telefono: 'telefono não é permitido' }

  @negativo
  Scenario: Un body vacío devuelve los cuatro campos obligatorios
    Given path 'usuarios'
    And request {}
    When method post
    Then status 400
    And match response ==
      """
      {
        nome: 'nome é obrigatório',
        email: 'email é obrigatório',
        password: 'password é obrigatório',
        administrador: 'administrador é obrigatório'
      }
      """

  # HALLAZGO: la API trata el email como sensible a mayúsculas, así que deja registrar
  # "Ana@correo.com" aunque ya exista "ana@correo.com". Los emails no distinguen mayúsculas en la
  # práctica, por lo que espero un 400. Está marcado con @hallazgo y excluido de la ejecución
  # normal; se corre a propósito para ver el defecto (instrucciones en el README).
  @hallazgo @negativo
  Scenario: No se debería registrar el mismo email escrito con otras mayúsculas
    * def existente = crearUsuario()
    * set usuario.email = existente.usuario.email.toUpperCase()
    Given path 'usuarios'
    And request usuario
    When method post
    # Si el defecto sigue, la API crea el usuario; lo registro para limpiarlo igual.
    * if (response._id) limpiarDespues(response._id)
    Then status 400
    And match response == { message: '#(msg.emailEnUso)' }
