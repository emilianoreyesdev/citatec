
const fs = require('node:fs');
const path = require('node:path');

const {
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: 'citatec-dev',
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8'
      ),
    },
  });

  try {
    // Buscar una cita existente sin modificarla.
    const citaId = await testEnv.withSecurityRulesDisabled(
      async (context) => {
        const db = context.firestore();

        const resultado = await db
          .collection('citas')
          .where('userName', '==', 'prueba.citatec@gmail.com')
          .get();

        const citaActiva = resultado.docs.find(
          (documento) => documento.data().estado === 'Activa'
        );

        if (!citaActiva) {
          throw new Error(
            'No se encontro una cita activa del primer estudiante.'
          );
        }

        return citaActiva.id;
      }
    );

    console.log('Cita localizada para pruebas.');

    // Simular otro estudiante autenticado.
    const intruso = testEnv.authenticatedContext(
      'estudiante-intruso-de-prueba',
      { email: 'intruso@example.com' }
    );

    const citaAjena = intruso
      .firestore()
      .collection('citas')
      .doc(citaId);

    async function verificarDenegacion(operacion, descripcion) {
      try {
        await operacion();
        throw new Error(
          `FALLO DE SEGURIDAD: ${descripcion} fue permitida.`
        );
      } catch (error) {
        if (
          error.code === 'permission-denied' ||
          error.code === 'firestore/permission-denied'
        ) {
          console.log(`OK: ${descripcion} bloqueada`);
          return;
        }

        throw error;
      }
    }

    await verificarDenegacion(
      () => citaAjena.get(),
      'Lectura ajena'
    );

    await verificarDenegacion(
      () => citaAjena.update({
        servicio: 'Servicio alterado',
      }),
      'Modificacion ajena'
    );

    await verificarDenegacion(
      () => citaAjena.delete(),
      'Eliminacion ajena'
    );

    console.log('PRUEBAS DE SEGURIDAD SUPERADAS');
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error('PRUEBA FALLIDA:', error);
  process.exitCode = 1;
});
