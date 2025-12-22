import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

import admin from 'firebase-admin';

function getArg(name) {
  const idx = process.argv.indexOf(`--${name}`);
  if (idx === -1) return undefined;
  const value = process.argv[idx + 1];
  if (!value || value.startsWith('--')) return undefined;
  return value;
}

function hasFlag(name) {
  return process.argv.includes(`--${name}`);
}

function requireArg(name) {
  const v = getArg(name);
  if (!v) {
    console.error(`Missing required argument: --${name}`);
    process.exit(2);
  }
  return v;
}

const serviceAccountPath = getArg('serviceAccount') ?? process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!serviceAccountPath) {
  console.error('Provide service account json via --serviceAccount <path> or env GOOGLE_APPLICATION_CREDENTIALS');
  process.exit(2);
}

const resolvedServiceAccountPath = path.resolve(serviceAccountPath);
if (!fs.existsSync(resolvedServiceAccountPath)) {
  console.error(`Service account json not found: ${resolvedServiceAccountPath}`);
  process.exit(2);
}

const projectId = getArg('projectId');

const serviceAccount = JSON.parse(fs.readFileSync(resolvedServiceAccountPath, 'utf-8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  ...(projectId ? { projectId } : {}),
});

const firestore = admin.firestore();

const email = getArg('email');
let uid = getArg('uid');

const createAuth = hasFlag('createAuth');
const password = getArg('password');
const nome = getArg('nome') ?? undefined;

async function resolveUid() {
  if (uid) return uid;
  if (!email) {
    console.error('You must provide --uid <uid> or --email <email>');
    process.exit(2);
  }

  try {
    const user = await admin.auth().getUserByEmail(email);
    uid = user.uid;
    return uid;
  } catch (err) {
    if (!createAuth) {
      console.error(`Auth user not found for email ${email}. Use --createAuth to create it.`);
      throw err;
    }
    if (!password) {
      console.error('To create auth user, provide --password <password>');
      process.exit(2);
    }

    const user = await admin.auth().createUser({
      email,
      password,
      displayName: nome,
    });
    uid = user.uid;
    return uid;
  }
}

async function upsertSuperuserDoc(userUid) {
  const docRef = firestore.collection('usuarios').doc(userUid);
  const snap = await docRef.get();

  const base = {
    tipo: 'superuser',
    ativo: true,
    atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
  };

  // Preserve existing fields; only fill missing basic fields.
  const existing = snap.exists ? snap.data() : {};

  const payload = {
    ...base,
    ...(existing?.criadoEm ? {} : { criadoEm: admin.firestore.FieldValue.serverTimestamp() }),
    ...(email ? { email } : {}),
    ...(nome ? { nome } : {}),
  };

  await docRef.set(payload, { merge: true });
}

(async () => {
  try {
    const userUid = await resolveUid();
    await upsertSuperuserDoc(userUid);

    console.log('OK: user promoted to superuser');
    console.log(`uid: ${userUid}`);
    if (email) console.log(`email: ${email}`);
  } catch (err) {
    console.error('FAILED:', err?.message ?? err);
    process.exit(1);
  }
})();
