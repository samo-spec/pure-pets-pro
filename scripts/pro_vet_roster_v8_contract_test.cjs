'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..', 'PurePetsPro');
const view = fs.readFileSync(path.join(root,'VeterinarianSection','PPVetsListViewController.m'),'utf8');
const cell = fs.readFileSync(path.join(root,'VeterinarianSection','PPVetCell.m'),'utf8');
const header = fs.readFileSync(path.join(root,'VeterinarianSection','PPVetCell.h'),'utf8');
const ar = fs.readFileSync(path.join(root,'ar.lproj','Localizable.strings'),'utf8');
const en = fs.readFileSync(path.join(root,'en.lproj','Localizable.strings'),'utf8');

test('compact roster uses one count source; no duplicate hero telemetry cards',()=>{
  assert.match(view,/Vet_Roster_Title/);
  assert.match(view,/Vet_Roster_Summary_Format/);
  assert.doesNotMatch(view,/metricCardWithTitle|self\.metricStack/);
  assert.match(view,/UIStackViewDistributionFillEqually/);
});
test('preserves provider ownership, native search/filter, list and inspector contracts',()=>{
  for(const s of ['pp_currentUserOwnsVet:', 'observeAllVets:', 'pp_canManageVetWorkspace', 'setActiveFilter:', 'applyFilterAndReload', 'updateInspectorWithVet:', 'PPVetDetailViewController','PPVetSubscriptionViewController','addVetTapped','contextMenuConfigurationForRowAtIndexPath']) assert.ok(view.includes(s),s);
});
test('veterinarian identity and actions are content-first, accessible and minimally 44 points',()=>{
  assert.match(cell,/UIStackView.*initWithArrangedSubviews/s);
  assert.match(cell,/constraintEqualToConstant:44\.0/);
  assert.match(cell,/onCallTapped/);
  assert.match(cell,/onWhatsAppTapped/);
  assert.match(cell,/onToggleStatusTapped/);
  assert.match(header,/canManageStatus/);
  assert.match(view,/cell\.canManageStatus\s*=\s*\[self pp_canManageVetWorkspace\]/);
});
test('roster supports dynamic sizes, semantic Arabic/English and honest missing details',()=>{
  assert.match(cell,/PPEnableDynamicType/);
  assert.match(cell,/Language\.semanticAttributeForCurrentLanguage/);
  assert.doesNotMatch(cell,/Available for veterinary consultations & pet care/);
  for(const key of ['Vet_Roster_Title','Vet_Roster_Summary_Format','Vet_Action_Call','Vet_Action_WhatsApp']){
    for(const [label, strings] of [['Arabic',ar],['English',en]]) assert.ok(strings.includes(`"${key}"`),`${label}: ${key}`);
  }
});
test('loading failure has a visible retry route without weakening Firestore ownership',()=>{
  assert.match(view,/emptyRetryButton/);
  assert.match(view,/@selector\(retryVetLoadTapped\)/);
  assert.match(view,/- \(void\)retryVetLoadTapped/);
  assert.match(view,/\[self\.listener remove\]/);
  for(const loc of [ar,en]) assert.ok(loc.includes('"Vet_Roster_Retry"'));
});

test('V8 clinical passport has an authored identity stage, semantic state rail and a distinct action dock', () => {
  assert.match(cell, /statusRail/);
  assert.match(cell, /identityColumn/);
  assert.match(cell, /profileActionButton/);
  assert.match(cell, /feeColumn/);
  assert.match(cell, /actionDock/);
  assert.doesNotMatch(cell, /onlineDot/);
  assert.match(cell, /Vet_Roster_View_Profile/);
  assert.match(cell, /Vet_Roster_Fee_Label/);
});

test('state cannot masquerade as live presence, and unavailable actions remain absent', () => {
  assert.match(cell, /self\.callButton\.hidden\s*=\s*\(vet\.phone\.length\s*==\s*0\)/);
  assert.match(cell, /self\.whatsappButton\.hidden\s*=\s*\(vet\.whatsapp\.length\s*==\s*0\)/);
  assert.match(cell, /if \(!self\.canManageStatus\) return/);
  assert.match(cell, /isSubscriptionExpired/);
  assert.match(cell, /PPMotionReduced\(\)/);
  assert.match(cell, /UIAccessibilityIsReduceMotionEnabled/);
});

test('every primary action has a 44-point touch target and accessible label', () => {
  for (const name of ['profileActionButton', 'callButton', 'whatsappButton', 'statusToggleButton']) {
    assert.match(cell, new RegExp(`${name}.*heightAnchor.*44\\.0`, 's'));
  }
  for (const key of ['Vet_Roster_View_Profile', 'Vet_Roster_Fee_Label']) {
    for (const strings of [ar, en]) assert.ok(strings.includes(`"${key}"`));
  }
});

test('large accessibility text reflows state and the action dock instead of squeezing buttons', () => {
  assert.match(cell, /pp_applyAccessibilityLayout/);
  assert.match(cell, /self\.actionDock\.axis\s*=\s*expanded\s*\?/);
  assert.match(cell, /self\.stateFeeBand\.axis\s*=\s*expanded\s*\?/);
  assert.match(cell, /self\.callWidthConstraint\.active\s*=\s*!expanded/);
  assert.match(cell, /self\.whatsappWidthConstraint\.active\s*=\s*!expanded/);
  assert.match(cell, /self\.callButton setTitle:/);
  assert.match(cell, /self\.whatsappButton setTitle:/);
});
