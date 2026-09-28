function fn() {
  // Ambiente por defecto: la API pública. Con -Dkarate.env=local apunto a un ServeRest
  // levantado en mi máquina (npx serverest), que es lo que uso para no ensuciar la data pública.
  var env = karate.env || 'prod';
  var urls = {
    prod: 'https://serverest.dev',
    local: 'http://localhost:3000'
  };
  if (!urls[env] && !karate.properties['baseUrl']) {
    karate.fail('Ambiente desconocido: ' + env + '. Usa prod, local o pasa -DbaseUrl=<url>');
  }

  var config = {
    env: env,
    // -DbaseUrl tiene prioridad, por si hay que apuntar a otro servidor sin tocar este archivo.
    baseUrl: karate.properties['baseUrl'] || urls[env],
    // Tiempo máximo de respuesta que acepto en los escenarios @smoke (ver verificarTiempo abajo).
    slaMs: parseInt(karate.properties['slaMs'] || '3000'),
    // Contra un ServeRest local el tiempo mide a la API y el umbral se exige. Contra la API pública
    // mide sobre todo internet y un servidor compartido que no controlo: ahí solo aviso, para que
    // un pico de red no tumbe la suite. Con -DslaEstricto=true se exige en cualquier ambiente.
    slaEstricto: env == 'local' || karate.properties['slaEstricto'] == 'true',
    // Generador de datos de prueba (clase Java en serverest/helpers).
    datos: Java.type('serverest.helpers.UsuarioDataFactory'),
    // Mensajes que devuelve la API. Los centralizo acá porque la API está en portugués y
    // así, si algún mensaje cambia, se corrige en un solo lugar.
    msg: read('classpath:serverest/common/mensajes.json'),
    // Esquemas de respuesta, para reutilizarlos en todos los features.
    // usuarioSchema es estricto (formato de _id, email y administrador) y lo aplico a los usuarios
    // que crea la suite. usuarioEnListaSchema solo valida campos y tipos, y lo uso para la lista
    // completa, que en la API pública trae usuarios de otras personas que no controlo.
    usuarioSchema: read('classpath:serverest/schemas/usuario.json'),
    usuarioEnListaSchema: read('classpath:serverest/schemas/usuario-en-lista.json'),
    listaUsuariosSchema: read('classpath:serverest/schemas/lista-usuarios.json'),
    registroSchema: read('classpath:serverest/schemas/registro-exitoso.json')
  };

  // Limpieza automática: cada escenario que crea algo en la API (usuario, producto o carrito) lo
  // registra con estas funciones, y al terminar el escenario (pase o falle) borro todo lo que quedó
  // registrado. Lo hago en el afterScenario y no como último paso porque si una aserción falla a la
  // mitad, los pasos siguientes no se ejecutan y los datos quedarían huérfanos en la API pública.
  config.limpiarDespues = function (id) {
    var ids = karate.get('idsCreados') || [];
    ids.push(id);
    karate.set('idsCreados', ids);
  };
  // Lo mismo para carritos y productos (solo los usa el escenario del usuario con carrito).
  // Guardo el token porque la API los identifica por el usuario logueado y exige autorización.
  config.limpiarCarritoDespues = function (token) {
    var tokens = karate.get('carritosCreados') || [];
    tokens.push(token);
    karate.set('carritosCreados', tokens);
  };
  config.limpiarProductoDespues = function (id, token) {
    var productos = karate.get('productosCreados') || [];
    productos.push({ id: id, token: token });
    karate.set('productosCreados', productos);
  };
  // Atajo para los escenarios donde el usuario es solo una precondición: lo crea (con los datos
  // que le pase o con uno generado) y lo deja registrado para la limpieza.
  // Nota: Karate no conserva closures en las funciones de este archivo, por eso aquí vuelvo a
  // leer todo con karate.get() en lugar de usar las variables de arriba.
  config.crearUsuario = function (usuario) {
    var body = usuario || karate.get('datos').usuarioValido();
    var creado = karate.call('classpath:serverest/common/crear-usuario.feature', { usuario: body });
    karate.get('limpiarDespues')(creado.id);
    return { id: creado.id, usuario: body };
  };
  // El orden importa: la API no deja borrar un producto que está en un carrito ni un usuario que
  // tiene carrito. Por eso primero cancelo los carritos (eso además devuelve el stock), después
  // borro los productos y al final los usuarios. Si el escenario ya limpió algo por su cuenta,
  // repetirlo no hace daño: la API responde 200 con "no encontrado" / "nada eliminado".
  config.verificarTiempo = function (ms) {
    var sla = karate.get('slaMs');
    if (ms <= sla) return;
    var mensaje = 'La respuesta tardó ' + ms + ' ms y el umbral es ' + sla + ' ms';
    if (karate.get('slaEstricto')) {
      karate.fail(mensaje);
    } else {
      karate.log('ADVERTENCIA:', mensaje, '(no se exige contra la API pública)');
    }
  };
  karate.configure('afterScenario', function () {
    (karate.get('carritosCreados') || []).forEach(function (token) {
      karate.call('classpath:serverest/common/limpieza.feature@carrito', { token: token });
    });
    (karate.get('productosCreados') || []).forEach(function (producto) {
      karate.call('classpath:serverest/common/limpieza.feature@producto', producto);
    });
    (karate.get('idsCreados') || []).forEach(function (id) {
      karate.call('classpath:serverest/common/eliminar-usuario.feature', { id: id });
    });
  });

  karate.configure('connectTimeout', 10000);
  karate.configure('readTimeout', 20000);
  // Formateo los JSON de request/response para que se lean bien en el log y en el reporte HTML.
  karate.configure('logPrettyRequest', true);
  karate.configure('logPrettyResponse', true);

  karate.log('Ejecutando contra', config.baseUrl, '(env=' + env + ')');
  return config;
}
