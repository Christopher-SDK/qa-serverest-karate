@ignore
Feature: Crear un usuario (reutilizable)
  # No es una prueba: es un paso de preparación que llaman los otros features a través de
  # crearUsuario() (karate-config.js). Espera la variable "usuario" con el body a enviar.

  Scenario:
    Given url baseUrl
    And path 'usuarios'
    And request usuario
    When method post
    # Si la creación falla, prefiero que el escenario que me llamó se corte aquí con este status
    # y no más adelante con un error confuso.
    Then status 201
    * def id = response._id
