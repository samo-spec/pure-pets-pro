const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.join(__dirname,'../PurePetsPro');
const s=fs.readFileSync(path.join(root,'SceneDelegate.m'),'utf8');
const f=fs.readFileSync(path.join(root,'AdminCore/Security/FUManager.m'),'utf8');
assert(s.includes('pp_pendingNotificationEpoch') && s.includes('pp_pendingCompanyDeliveryEpoch'), 'deferred routes must carry their origin epoch');
assert(s.includes('pp_notificationEpochIsCurrent:'), 'route consumption checks original epoch');
assert(f.includes('bootstrapGeneration'), 'bootstrap listener must fence its profile');
assert(f.includes('bootstrapTransactionGeneration'), 'bootstrap transaction must fence A-B-A');
console.log('PASS deferred route and Firebase bootstrap integration contracts');