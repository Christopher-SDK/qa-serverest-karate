@usuarios @listar
Feature: Listar usuarios - GET /usuarios
  Como administrador del sistema
  Quiero obtener la lista de usuarios, con o sin filtros
  Para consultar quiénes están registrados

  Background:
    # El path lo pongo en cada escenario y no aquí: en Karate "path" se acumula, y los escenarios
    # que crean un usuario antes de listar terminarían pidiendo /usuarios/usuarios.
    * url baseUrl

  @smoke @positivo
  Scenario: Obtener la lista de todos los usuarios
    Given path 'usuarios'
    When method get
    Then status 200
    And match response == listaUsuariosSchema
    # "quantidade" tiene que coincidir con el largo real del arreglo; si no, el contador miente.
    And match response.quantidade == response.usuarios.length
    And assert responseTime < slaMs

  @positivo
  Scenario: Un usuario recién registrado aparece en la lista
    * def creado = crearUsuario()
    Given path 'usuarios'
    When method get
    Then status 200
    And match response.usuarios contains karate.merge(creado.usuario, { _id: creado.id })

  @positivo
  Scenario Outline: Filtrar la lista por <campo> devuelve solo al usuario buscado
    * def creado = crearUsuario()
    * def valor = '<campo>' == '_id' ? creado.id : creado.usuario['<campo>']
    Given path 'usuarios'
    And param <campo> = valor
    When method get
    Then status 200
    And match response.quantidade == 1
    And match response.usuarios[0] == karate.merge(creado.usuario, { _id: creado.id })

    # Filtro solo por campos que en mis datos son únicos (email e _id). Filtrar por nombre o
    # password podría traer otros usuarios de la base pública y el conteo no sería confiable.
    Examples:
      | campo |
      | email |
      | _id   |

  @positivo
  Scenario Outline: Filtrar por administrador=<admin> devuelve solo usuarios con ese perfil
    # Creo uno de cada perfil para asegurarme de que el filtro tiene algo que devolver
    # aunque la base esté vacía (por ejemplo, corriendo contra un ServeRest local recién levantado).
    * crearUsuario(datos.usuarioValido(true))
    * crearUsuario(datos.usuarioValido(false))
    Given path 'usuarios'
    And param administrador = '<admin>'
    When method get
    Then status 200
    And match response.quantidade == '#? _ >= 1'
    And match each response.usuarios contains { administrador: '<admin>' }

    Examples:
      | admin |
      | true  |
      | false |

  @positivo
  Scenario: Combinar filtros que no coinciden devuelve una lista vacía
    * def creado = crearUsuario(datos.usuarioValido(true))
    Given path 'usuarios'
    And params { email: '#(creado.usuario.email)', administrador: 'false' }
    When method get
    Then status 200
    And match response == { quantidade: 0, usuarios: [] }

  @negativo
  Scenario: Filtrar por un email que no existe devuelve una lista vacía y no un error
    Given path 'usuarios'
    And param email = datos.emailUnico()
    When method get
    Then status 200
    And match response == { quantidade: 0, usuarios: [] }

  @negativo
  Scenario Outline: Filtrar por administrador con un valor inválido (<valor>) devuelve 400
    Given path 'usuarios'
    And param administrador = '<valor>'
    When method get
    Then status 400
    And match response == { administrador: '#(msg.adminInvalido)' }

    Examples:
      | valor |
      | si    |
      | TRUE  |
      | 1     |

  @negativo
  Scenario: Enviar un parámetro de búsqueda que no existe devuelve 400
    Given path 'usuarios'
    And param apellido = 'Perez'
    When method get
    Then status 400
    And match response == { apellido: 'apellido não é permitido' }
