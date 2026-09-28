@ignore
Feature: Eliminar un usuario (reutilizable, se usa para limpiar datos de prueba)

  Scenario:
    * url baseUrl
    * path 'usuarios', id
    * method delete
    * karate.log('limpieza', id, '->', response.message)
