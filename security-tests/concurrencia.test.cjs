const fs = require('node:fs');
const path = require('node:path');
const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');

// Fecha futura de prueba. Cámbiala si ya pasó o si el horario está ocupado.
const FECHA = new Date(Date.UTC(2026, 10, 3));
const DEPARTAMENTO = 'Servicios Escolares';
const HORA = '02:00 PM';
const HORARIO_ID = `${DEPARTAMENTO}|${FECHA.getUTCFullYear()}|${FECHA.getUTCMonth() + 1}|${FECHA.getUTCDate()}|${HORA}`;

const USUARIOS = [
  { uid: 'concurrencia-estudiante-a', email: 'concurrencia-a@example.com' },
  { uid: 'concurrencia-estudiante-b', email: 'concurrencia-b@example.com' },
];

async function main() {
  const env = await initializeTestEnvironment({
    projectId: 'citatec-dev',
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });

  // IDs creados por la prueba, nunca IDs de estudiantes reales.
  const idsDePrueba = new Set();
  let horarioLibreAlInicio = false;

  try {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      const [privado, publico, citas] = await Promise.all([
        db.collection('horarios_ocupados').doc(HORARIO_ID).get(),
        db.collection('disponibilidad_horarios').doc(HORARIO_ID).get(),
        db.collection('citas').where('horarioId', '==', HORARIO_ID).where('estado', '==', 'Activa').get(),
      ]);
      if (privado.exists || publico.exists || !citas.empty) {
        throw new Error(`El horario ${HORARIO_ID} ya tiene una reserva o datos inconsistentes. Elige otro horario libre en el test.`);
      }
      horarioLibreAlInicio = true;
    });

    async function reservar(usuario) {
      const ctx = env.authenticatedContext(usuario.uid, { email: usuario.email });
      const db = ctx.firestore();
      const citaRef = db.collection('citas').doc();
      idsDePrueba.add(citaRef.id);
      const privadoRef = db.collection('horarios_ocupados').doc(HORARIO_ID);
      const publicoRef = db.collection('disponibilidad_horarios').doc(HORARIO_ID);
      const fecha = firebase.firestore.Timestamp.fromDate(FECHA);

      // Mismo protocolo de Citatec: leer SOLO disponibilidad pública.
      const creada = await db.runTransaction(async (tx) => {
        const publico = await tx.get(publicoRef);
        if (publico.exists) return false;

        tx.set(citaRef, {
          userId: usuario.uid,
          userName: usuario.email,
          departamento: DEPARTAMENTO,
          servicio: 'Constancia de estudios',
          fecha,
          hora: HORA,
          estado: 'Activa',
          horarioId: HORARIO_ID,
          created_at: firebase.firestore.FieldValue.serverTimestamp(),
        });
        tx.set(privadoRef, {
          citaId: citaRef.id,
          userId: usuario.uid,
          departamento: DEPARTAMENTO,
          fecha,
          hora: HORA,
        });
        tx.set(publicoRef, { ocupado: true });
        return true;
      });
      if (!creada) throw new Error('HORARIO_OCUPADO');
      return { uid: usuario.uid, citaId: citaRef.id };
    }

    console.log(`Probando concurrencia en ${HORARIO_ID}`);
    const resultados = await Promise.allSettled(USUARIOS.map(reservar));
    resultados.forEach((r, i) => console.log(
      `Estudiante ${i + 1}: ${r.status === 'fulfilled' ? 'ACEPTADO' : 'RECHAZADO ' + String(r.reason)}`
    ));

    const aceptados = resultados.filter((r) => r.status === 'fulfilled');
    const rechazados = resultados.filter((r) => r.status === 'rejected');

    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      const [privado, publico, citas] = await Promise.all([
        db.collection('horarios_ocupados').doc(HORARIO_ID).get(),
        db.collection('disponibilidad_horarios').doc(HORARIO_ID).get(),
        db.collection('citas').where('horarioId', '==', HORARIO_ID).where('estado', '==', 'Activa').get(),
      ]);
      if (aceptados.length !== 1 || rechazados.length !== 1 ||
          !privado.exists || !publico.exists || publico.data().ocupado !== true ||
          citas.size !== 1 || citas.docs[0].id !== privado.data().citaId ||
          citas.docs[0].id !== aceptados[0].value.citaId ||
          privado.data().userId !== aceptados[0].value.uid) {
        throw new Error('No se confirmó una única reserva consistente en las tres colecciones.');
      }
    });
    console.log('PRUEBA SUPERADA: exactamente una reserva confirmada y tres documentos sincronizados.');
  } finally {
    try {
      if (horarioLibreAlInicio) {
        await env.withSecurityRulesDisabled(async (ctx) => {
          const db = ctx.firestore();
          const privadoRef = db.collection('horarios_ocupados').doc(HORARIO_ID);
          const publicoRef = db.collection('disponibilidad_horarios').doc(HORARIO_ID);
          const privado = await privadoRef.get();
          // Sólo retirar ocupaciones creadas por este test.
          if (privado.exists && idsDePrueba.has(privado.data().citaId) &&
              USUARIOS.some((u) => u.uid === privado.data().userId)) {
            await privadoRef.delete();
            await publicoRef.delete();
          }
          for (const id of idsDePrueba) {
            const citaRef = db.collection('citas').doc(id);
            const cita = await citaRef.get();
            if (cita.exists && cita.data().horarioId === HORARIO_ID &&
                USUARIOS.some((u) => u.uid === cita.data().userId)) {
              await citaRef.delete();
            }
          }
        });
      }
    } finally {
      await env.cleanup();
    }
  }
}

main().catch((error) => {
  console.error('PRUEBA FALLIDA:', error);
  process.exitCode = 1;
});
