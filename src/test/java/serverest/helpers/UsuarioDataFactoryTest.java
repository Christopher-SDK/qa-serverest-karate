package serverest.helpers;

import org.junit.jupiter.api.Test;

import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Pruebas rápidas del generador. Si el generador se rompe, prefiero enterarme aquí con un error
 * claro y no con 30 escenarios de API fallando por "email já está sendo usado".
 */
class UsuarioDataFactoryTest {

    @Test
    void generaUsuarioConLosCuatroCamposQuePideLaApi() {
        Map<String, Object> usuario = UsuarioDataFactory.usuarioValido(true);

        assertEquals(Set.of("nome", "email", "password", "administrador"), usuario.keySet());
        assertEquals("true", usuario.get("administrador"));
        assertTrue(usuario.get("email").toString().matches("[^@\\s]+@[^@\\s]+\\.[a-z]{2,}"));
    }

    @Test
    void losEmailsNoSeRepiten() {
        Set<String> emails = new HashSet<>();
        for (int i = 0; i < 1000; i++) {
            emails.add(UsuarioDataFactory.emailUnico());
        }
        assertEquals(1000, emails.size());
    }

    @Test
    void elIdInexistenteTieneElFormatoQueExigeLaApi() {
        assertTrue(UsuarioDataFactory.idInexistente().matches("[a-zA-Z0-9]{16}"));
    }
}
