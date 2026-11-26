// Source integration checks; standalone fence behavior is tested in pro_session_fence_test.m.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const src = fs.readFileSync(path.join(__dirname, '../PurePetsPro/AdminCore/Models/UserManager.m'), 'utf8');
function method(start, end) {
  const a = src.indexOf(start); const b = src.indexOf(end, a+start.length);
  assert(a >= 0 && b > a, start);
  return src.slice(a,b);
}
for (const [start,end,min] of [
  ['- (void)fetchAdminWithUID:', '- (void)loadUserByUIDOrID:', 3],
  ['- (void)loadUserByUIDOrID:', '- (void)lookupUserByUIDOrID:', 3],
  ['- (void)startListeningUserWithUID:', '- (void)stopListening', 2],
  ['- (void)ensureUserDocumentExistsForAuthUser:', '#pragma mark - Permissions Helpers', 3],
]) {
  const block = method(start,end);
  assert(block.includes('pp_captureSessionForUID:'), start + ' must capture the current session');
  assert((block.match(/pp_sessionAllows:/g) || []).length >= min, start + ' must fence entry and async results');
}
const logout = method('- (void)signOut {', '#pragma mark - Ensure User Document');
assert(logout.includes('[strongSelf.sessionFence invalidate]'), 'successful logout must invalidate the generation');
const stop = method('- (void)stopListening {', '#pragma mark - Create if not exists');
assert(stop.includes('self.userListenerGeneration = nil'), 'detached listeners must reject late callbacks');
console.log('PASS session fence integration contracts');
