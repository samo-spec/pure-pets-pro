const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const src=fs.readFileSync(path.join(__dirname,'../PurePetsPro/AdminCore/Security/PPProFirebaseAccountRuntime.m'),'utf8');
for(const seam of ['configureWithName:','authWithApp:','firestoreForApp:','functionsForApp:','storageForApp:','providerWithAuth:','getIDTokenResultForcingRefresh:YES','waitForPendingWritesWithCompletion:']) assert(src.includes(seam), 'missing named-app SDK seam '+seam);
assert(!src.includes('[FIRAuth auth]') && !src.includes('[FIRFirestore firestore]'), 'slot cannot use default identity or database');
assert(src.includes('rolloutEnabled'), 'uncertified named-app runtime stays gated');
console.log('PASS named Firebase account runtime source contracts');