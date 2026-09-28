@ignore
Feature: Limpieza de carritos y productos (reutilizable, la usa el afterScenario)
  # No valido el status a propósito: si el escenario ya lo había limpiado, la API responde que no
  # encontró nada (o que el token ya no sirve, porque el usuario dueño ya se borró), y eso está bien.
  # Solo lo dejo en el log para poder revisarlo.

  Background:
    * url baseUrl

  @carrito
  Scenario: Cancelar el carrito del usuario dueño del token
    Given path 'carrinhos', 'cancelar-compra'
    And header Authorization = token
    When method delete
    * karate.log('limpieza carrito ->', response.message)

  @producto
  Scenario: Eliminar un producto
    Given path 'produtos', id
    And header Authorization = token
    When method delete
    * karate.log('limpieza producto', id, '->', response.message)
