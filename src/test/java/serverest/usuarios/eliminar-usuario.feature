@usuarios @eliminar
Feature: Eliminar usuario - DELETE /usuarios/{_id}
  Como administrador del sistema
  Quiero eliminar usuarios
  Para mantener limpia la base de datos

  Background:
    * url baseUrl

  @smoke @positivo
  Scenario: Eliminar un usuario existente
    * def creado = crearUsuario()
    Given path 'usuarios', creado.id
    When method delete
    Then status 200
    And match response == { message: '#(msg.eliminado)' }
    And verificarTiempo(responseTime)

    # Verifico que de verdad ya no existe.
    Given path 'usuarios', creado.id
    When method get
    Then status 400
    And match response == { message: '#(msg.noEncontrado)' }

  @negativo
  Scenario: Eliminar un ID que no existe no falla pero avisa que no borró nada
    Given path 'usuarios', datos.idInexistente()
    When method delete
    Then status 200
    And match response == { message: '#(msg.nadaEliminado)' }

  @negativo
  Scenario: Eliminar dos veces el mismo usuario
    # El segundo DELETE tiene que ser inofensivo (idempotente): no debe dar error ni borrar otra cosa.
    * def creado = crearUsuario()
    Given path 'usuarios', creado.id
    When method delete
    Then status 200
    And match response.message == msg.eliminado

    Given path 'usuarios', creado.id
    When method delete
    Then status 200
    And match response.message == msg.nadaEliminado

  @negativo @regla-negocio
  Scenario: No se puede eliminar un usuario que tiene un carrito
    # Esta es la única regla de negocio de DELETE /usuarios. Para probarla necesito un carrito real,
    # así que armo todo desde cero con datos propios: un admin, un producto suyo y un carrito.
    # No reutilizo productos existentes porque en la API pública pueden quedarse sin stock.
    * def creado = crearUsuario(datos.usuarioValido(true))

    Given path 'login'
    And request { email: '#(creado.usuario.email)', password: '#(creado.usuario.password)' }
    When method post
    Then status 200
    * def token = response.authorization

    Given path 'produtos'
    And header Authorization = token
    And request { nome: '#(datos.nombreProductoUnico())', preco: 100, descricao: 'Producto de prueba', quantidade: 5 }
    When method post
    Then status 201
    * def productoId = response._id
    * limpiarProductoDespues(productoId, token)

    Given path 'carrinhos'
    And header Authorization = token
    And request { produtos: [{ idProduto: '#(productoId)', quantidade: 1 }] }
    When method post
    Then status 201
    * def carritoId = response._id
    * limpiarCarritoDespues(token)

    # Lo que realmente estoy probando:
    Given path 'usuarios', creado.id
    When method delete
    Then status 400
    And match response == { message: '#(msg.tieneCarrito)', idCarrinho: '#(carritoId)' }

    # Ahora deshago todo en orden y así confirmo también que, sin carrito, el usuario sí se puede
    # eliminar. Si algo de lo anterior falla, el afterScenario cancela el carrito, borra el producto
    # y borra el usuario por mí (en ese orden), así que no queda nada en la API.
    Given path 'carrinhos', 'cancelar-compra'
    And header Authorization = token
    When method delete
    Then status 200

    Given path 'produtos', productoId
    And header Authorization = token
    When method delete
    Then status 200

    Given path 'usuarios', creado.id
    When method delete
    Then status 200
    And match response.message == msg.eliminado
