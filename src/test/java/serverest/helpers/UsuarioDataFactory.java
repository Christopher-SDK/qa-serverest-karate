package serverest.helpers;

import net.datafaker.Faker;

import java.security.SecureRandom;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

/**
 * Generador de datos de prueba para la API de usuarios.
 *
 * Lo hice en Java (y no en JavaScript dentro del feature) por dos motivos: puedo usar Datafaker
 * para tener nombres realistas, y queda aislado en un solo lugar que cualquier feature llama con
 * {@code datos.usuarioValido()}.
 *
 * La regla más importante acá: el email SIEMPRE es único. ServeRest es una API pública compartida
 * por mucha gente; si usara emails fijos, mis pruebas chocarían con usuarios que creó otra persona
 * (o con los de una ejecución anterior que falló a medias).
 */
public final class UsuarioDataFactory {

    // Prefijo para reconocer a simple vista los usuarios que crea esta suite en la base compartida.
    private static final String PREFIJO_EMAIL = "karate.qa.";
    private static final String DOMINIO_EMAIL = "@serverest-test.com";
    private static final String ALFANUMERICO = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

    private static final Faker FAKER = new Faker(Locale.forLanguageTag("es"));
    private static final SecureRandom RANDOM = new SecureRandom();

    private UsuarioDataFactory() {
        // Solo métodos estáticos: así Karate lo usa directo con Java.type() sin instanciarlo.
    }

    /** Usuario válido con perfil administrador elegido al azar. */
    public static Map<String, Object> usuarioValido() {
        return usuarioValido(RANDOM.nextBoolean());
    }

    /**
     * Usuario válido con el perfil indicado. Devuelvo un Map (y no un POJO) porque Karate lo
     * convierte directo a JSON y lo puedo modificar en el feature con set/remove.
     * Uso LinkedHashMap para que los campos salgan siempre en el mismo orden en los logs.
     */
    public static Map<String, Object> usuarioValido(boolean administrador) {
        Map<String, Object> usuario = new LinkedHashMap<>();
        usuario.put("nome", nombre());
        usuario.put("email", emailUnico());
        usuario.put("password", password());
        // La API espera el booleano como texto: "true" o "false".
        usuario.put("administrador", String.valueOf(administrador));
        return usuario;
    }

    public static String nombre() {
        return FAKER.name().fullName();
    }

    /** Email con un UUID recortado: prácticamente imposible que se repita entre ejecuciones o hilos. */
    public static String emailUnico() {
        String sufijo = UUID.randomUUID().toString().replace("-", "").substring(0, 12);
        return PREFIJO_EMAIL + sufijo + DOMINIO_EMAIL;
    }

    public static String password() {
        return FAKER.credentials().password(8, 16, true, true, true);
    }

    /**
     * Id con el formato correcto (16 caracteres alfanuméricos) pero que no existe.
     * Lo necesito para probar "usuario no encontrado" sin que falle antes por formato inválido.
     */
    public static String idInexistente() {
        StringBuilder id = new StringBuilder(16);
        for (int i = 0; i < 16; i++) {
            id.append(ALFANUMERICO.charAt(RANDOM.nextInt(ALFANUMERICO.length())));
        }
        return id.toString();
    }

    /** Nombre de producto único; lo uso solo en el escenario de usuario con carrito. */
    public static String nombreProductoUnico() {
        return "Producto QA Karate " + UUID.randomUUID().toString().substring(0, 8);
    }
}
