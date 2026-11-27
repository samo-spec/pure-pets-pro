const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname,'..','PurePetsPro');
const read = p => fs.readFileSync(path.join(root,p),'utf8');
const vault = read('AdminCore/Models/PPProRememberedAccountStore.m');
const surface = read('AdminCore/Auth/PPProLoginSurfaceController.swift');
const owner = read('AdminCore/Auth/AdminLoginViewController.m');
const router = read('SceneDelegate.m');
assert(vault.includes('+ (BOOL)rolloutEnabled') && (vault.includes('return YES;') || vault.includes('return NO;')), 'Account switching must remain explicitly controlled by rolloutEnabled');
assert(surface.includes('rememberedAccountSection') && surface.includes('selectedRememberedAccountUID'), 'Account selection is integrated into real login surface');
assert(owner.includes('PPProRememberedAccountStore rolloutEnabled') && owner.includes('recordsWithError:'), 'Login owns device account hints');
const sign = owner.slice(owner.indexOf('- (void)pp_signInWithCredential:'),owner.indexOf('- (NSString *)pp_friendlyFirebaseAuthErrorMessage:'));
assert(
  sign.includes('expectedUID') &&
    (sign.includes('signOutWithCompletion:') ||
      sign.includes('forceSecuritySignOutWithCompletion:') ||
      sign.includes('handleAuthenticationFailureForTicket:')),
  'Selected account mismatch must terminate authentication before routing'
);
assert(sign.indexOf('isEqualToString:expectedUID') < sign.indexOf('ensureUserDocumentExistsForCurrentUserWithExtra:'), 'Check account identity before profile bootstrap');
assert(router.includes('pp_rememberAuthorizedIdentity') && router.includes('PPProRememberedAccountStore rolloutEnabled'));
console.log('PASS remembered identity integration and guarded rollout contracts');
