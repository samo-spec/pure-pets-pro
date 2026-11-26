const assert = require('node:assert/strict');
const fs = require('node:fs');
const read = p => fs.readFileSync(require('node:path').join(__dirname,'../PurePetsPro',p),'utf8');
for (const file of ['AppDelegate.m','SceneDelegate.m','AdminCore/Auth/AdminLoginViewController.m']) {
 const source = read(file); assert(source.includes('PPProIdentityPortalUITest') && source.includes('#if DEBUG'), file+' must isolate fixture mode to Debug');
}
const surface = read('AdminCore/Auth/PPProLoginSurfaceController.swift');
assert(surface.includes('presentationTestMode') && surface.includes('pro.login.country.option.'));
console.log('PASS Debug-only UI fixture harness contract');
