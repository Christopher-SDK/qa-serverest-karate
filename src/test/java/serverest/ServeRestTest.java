package serverest;

import com.intuit.karate.Results;
import com.intuit.karate.Runner;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * Punto de entrada de la suite. Uso el Runner paralelo de Karate en vez de un @Karate.Test por
 * feature porque: 1) corre todo en paralelo, y 2) genera un único reporte consolidado.
 *
 * Los escenarios son independientes entre sí (cada uno crea y borra sus propios datos),
 * por eso puedo paralelizarlos sin miedo.
 */
class ServeRestTest {

    @Test
    void ejecutarSuite() {
        // Excluyo @ignore (features reutilizables que no son pruebas en sí) y @hallazgo (pruebas que
        // documentan defectos conocidos de la API; ver README).
        // Ojo: si paso -Dkarate.options="--tags @registrar", Karate REEMPLAZA los tags de abajo por
        // esos, y los @hallazgo se colarían en la ejecución. Por eso agrego la exclusión también a
        // karate.options, salvo que yo mismo esté pidiendo correr los hallazgos.
        String opciones = System.getProperty("karate.options", "");
        if (!opciones.contains("@hallazgo")) {
            System.setProperty("karate.options", opciones + " --tags ~@hallazgo");
        }

        Results results = Runner.path("classpath:serverest")
                .tags("~@ignore", "~@hallazgo")
                .outputCucumberJson(true)
                .outputJunitXml(true)
                .parallel(Integer.getInteger("threads", 5));

        assertEquals(0, results.getFailCount(), results.getErrorMessages());
    }
}
