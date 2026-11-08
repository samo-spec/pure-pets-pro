/* Run only against a local Firestore emulator. No production credentials used. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createRequire } = require('node:module');

const proRoot = path.resolve(__dirname, '..');
const infraRoot = path.resolve(proRoot, '../Pure Pets Infra');
const infraRequire = createRequire(path.join(infraRoot, 'functions/package.json'));
const { initializeTestEnvironment, assertSucceeds, assertFails } = infraRequire('@firebase/rules-unit-testing');
const { serverTimestamp, setLogLevel } = infraRequire('firebase/firestore');
const host = process.env.FIRESTORE_EMULATOR_HOST || '';
assert.match(host, /^(127\.0\.0\.1|localhost):\d+$/, 'A local emulator is required.');
const [hostname, port] = host.split(':');
const rules = fs.readFileSync(path.join(infraRoot, 'firestore.rules'), 'utf8');
const source = fs.readFileSync(path.join(proRoot, 'PurePetsPro/AdminCore/Security/FUManager.m'), 'utf8');
const bootstrap = source.slice(source.indexOf('- (void)p_createOrMergeUserDocFor:'), source.indexOf('- (void)ensureUserDocumentExistsForCurrentUserWithExtra:'));
assert(!bootstrap.includes('@"providerIds"'), 'Auth providers are not owner profile fields.');
assert(!bootstrap.includes('self.ref'), 'A login must not reuse another identity\'s mutable reference.');
assert(bootstrap.includes('runTransactionWithBlock:'), 'Profile creation time must survive concurrent bootstraps.');
assert(bootstrap.includes('if (!existing.exists) payload[@"createdAt"]'), 'Only the first creation sets createdAt.');

const createRule = rules.match(/function hasOnlySafeOwnerProfileCreateKeys\(data\) \{([\s\S]*?)\n    \}/)[1];
const updateRule = rules.match(/function hasOnlySafeOwnerProfileChanges\(userID\) \{([\s\S]*?)\]\)/)[1];
const allowedCreate = new Set([...createRule.matchAll(/'([^']+)'/g)].map(m => m[1]));
const allowedUpdate = new Set([...updateRule.matchAll(/'([^']+)'/g)].map(m => m[1]));
const extraKeys = [...bootstrap.match(/for \(NSString \*key in @\[([\s\S]*?)\]\)/)[1].matchAll(/@"([^"]+)"/g)].map(m => m[1]);
const writeKeys = [...bootstrap.matchAll(/(?:profile|payload)\[@"([^"]+)"\]|@"([^"]+)":/g)].map(m => m[1] || m[2]);
for (const key of new Set([...extraKeys, ...writeKeys])) {
  assert(allowedCreate.has(key), `Bootstrap create key is not allowed by Infra: ${key}`);
  if (key !== 'createdAt') assert(allowedUpdate.has(key), `Bootstrap update key is not allowed by Infra: ${key}`);
}

let env;
let passed = 0;
async function check(name, body) {
  await body();
  passed += 1;
  console.log(`PASS ${name}`);
}
function payload(uid) {
  return { uid, email: `${uid}@example.invalid`, displayName: 'Provider',
    updatedAt: serverTimestamp(), lastLoginAt: serverTimestamp() };
}
async function bootstrapProfile(db, uid) {
  const ref = db.doc(`UsersCol/${uid}`);
  await db.runTransaction(async tx => {
    const existing = await tx.get(ref);
    const data = payload(uid);
    if (!existing.exists) data.createdAt = serverTimestamp();
    tx.set(ref, data, { merge: true });
  });
}

(async () => {
  setLogLevel('silent');
  env = await initializeTestEnvironment({
    projectId: 'demo-purepets-pro-auth',
    firestore: { host: hostname, port: Number(port), rules },
  });
  const uid = 'pro-auth-owner';
  const owner = env.authenticatedContext(uid, { email_verified: true }).firestore();
  const ref = owner.doc(`UsersCol/${uid}`);

  await check('first-login bootstrap uses owner-safe fields', () => assertSucceeds(bootstrapProfile(owner, uid)));
  const createdAt = (await ref.get()).data().createdAt;
  await env.withSecurityRulesDisabled(async context => {
    await context.firestore().doc(`UsersCol/${uid}`).set({
      status: 'active', accountType: 'user', features: { serviceProvider: true },
      subscriptions: { serviceProvider: { status: 'active' } },
      providerIds: ['legacy-retained'],
    }, { merge: true });
  });
  await check('repeat/concurrent logins retain creation time and provider authority', async () => {
    await assertSucceeds(Promise.all([bootstrapProfile(owner, uid), bootstrapProfile(owner, uid)]));
    const data = (await ref.get()).data();
    assert(data.createdAt.isEqual(createdAt));
    assert.deepEqual(data.features, { serviceProvider: true });
    assert.deepEqual(data.subscriptions, { serviceProvider: { status: 'active' } });
    assert.deepEqual(data.providerIds, ['legacy-retained']);
  });
  await check('old providerIds mutation is rejected', () => assertFails(ref.set({ ...payload(uid), providerIds: ['google.com'] }, { merge: true })));
  await check('creation timestamp cannot be replaced', () => assertFails(ref.set({ ...payload(uid), createdAt: new Date(0) }, { merge: true })));
  await check('self provider-feature escalation is rejected', () => assertFails(ref.set({ ...payload(uid), features: { pharmacy: true } }, { merge: true })));
  await check('authenticated owner can read its profile by UID', () => assertSucceeds(ref.get()));
  await check('provider cannot enumerate profiles by UID query', () => assertFails(owner.collection('UsersCol').where('uid', '==', uid).get()));
  await check('a different account cannot complete the former account bootstrap', () => assertFails(env.authenticatedContext('another-account').firestore().doc(`UsersCol/${uid}`).set(payload(uid), { merge: true })));

  const first = env.authenticatedContext('first-google-user').firestore();
  await check('old first-login payload is rejected', () => assertFails(first.doc('UsersCol/first-google-user').set({ ...payload('first-google-user'), createdAt: serverTimestamp(), providerIds: ['google.com'] })));
  await check('corrected first-login payload succeeds', () => assertSucceeds(bootstrapProfile(first, 'first-google-user')));
  for (const status of ['blocked', 'suspended', 'disabled', 'deleted']) {
    const blockedUID = `pro-${status}`;
    await env.withSecurityRulesDisabled(async context => {
      await context.firestore().doc(`UsersCol/${blockedUID}`).set({ ...payload(blockedUID), status, createdAt: serverTimestamp() });
    });
    await check(`${status} account stays denied`, () => assertFails(bootstrapProfile(env.authenticatedContext(blockedUID).firestore(), blockedUID)));
  }
  console.log(`PASS ${passed} emulator regressions; source payload keys match Infra allowlists.`);
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
}).finally(async () => {
  if (env) await env.cleanup();
});
