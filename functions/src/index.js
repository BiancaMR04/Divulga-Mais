const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

async function assertCallerIsSuperuser(context) {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Login obrigatório.');
  }

  const callerUid = context.auth.uid;
  const snap = await admin.firestore().collection('usuarios').doc(callerUid).get();
  const tipo = (snap.exists ? String(snap.get('tipo') ?? '') : '').trim().toLowerCase();

  if (tipo !== 'superuser') {
    throw new functions.https.HttpsError('permission-denied', 'Apenas superuser.');
  }

  return callerUid;
}

// Callable: permite superuser excluir/desativar usuário no Firebase Auth.
// data: { uid: string, mode?: 'delete' | 'disable' }
exports.adminDeleteAuthUser = functions.https.onCall(async (data, context) => {
  await assertCallerIsSuperuser(context);

  const targetUid = typeof data?.uid === 'string' ? data.uid.trim() : '';
  const mode = typeof data?.mode === 'string' ? data.mode.trim().toLowerCase() : 'delete';

  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'uid é obrigatório.');
  }

  if (context.auth?.uid && targetUid === context.auth.uid) {
    throw new functions.https.HttpsError('failed-precondition', 'Não é permitido excluir o próprio usuário.');
  }

  try {
    if (mode === 'disable') {
      await admin.auth().updateUser(targetUid, { disabled: true });
      return { ok: true, mode: 'disable' };
    }

    await admin.auth().deleteUser(targetUid);
    return { ok: true, mode: 'delete' };
  } catch (err) {
    const code = String(err?.code ?? '');

    // Normaliza alguns erros comuns do Admin SDK.
    if (code.includes('auth/user-not-found')) {
      throw new functions.https.HttpsError('not-found', 'Usuário não encontrado no Auth.');
    }

    throw new functions.https.HttpsError('internal', `Falha ao alterar Auth: ${err?.message ?? err}`);
  }
});
