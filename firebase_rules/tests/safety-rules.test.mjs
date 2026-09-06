import { readFile } from 'node:fs/promises';
import { before, after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc, setDoc, getDoc, getDocs, collection, collectionGroup, query, where,
  updateDoc, writeBatch, serverTimestamp, Timestamp, Bytes, runTransaction,
} from 'firebase/firestore';

let env;
const sha = 'a'.repeat(64), hash = '0123456789abcdef';
const validation = {
  isValid: true, duplicateDetected: false, evidenceSource: 'CAMERA',
  semanticValidationAvailable: false, validationLevel: 'GOOD',
  qualityScore: .8, overallEvidenceScore: .8, sha256Fingerprint: sha,
  perceptualHash: hash, warnings: [],
};
const dbFor = uid => env.authenticatedContext(uid).firestore();
const reportRef = (db, id = 'report') => doc(db, 'hazard_reports', id);
const voteRef = (db, uid, id = 'report') => doc(db, 'hazard_reports', id, 'votes', uid);

function report(uid, id = 'report') {
  return {
    hazardId: id, userId: uid, category: 'Flooding', severity: 'High',
    description: 'Water across walkway', imageUrl: '', hasPhotoEvidence: true,
    evidenceStorage: 'firestore', evidenceValidationResult: validation,
    evidenceSha256: sha, evidencePerceptualHash: hash, evidenceSource: 'CAMERA',
    latitude: 5.4141, longitude: 100.3288, status: 'Pending Review',
    statusHistory: [{status: 'Pending Review', changedBy: uid, changedAt: Timestamp.now()}],
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  };
}
function photo(uid, id = 'report') {
  return {
    hazardId: id, userId: uid, imageBytes: Bytes.fromUint8Array(new Uint8Array([255,216,255,1])),
    byteLength: 4, contentType: 'image/jpeg', sourceSha256: sha, perceptualHash: hash,
    validationLevel: 'GOOD', evidenceSource: 'CAMERA', createdAt: serverTimestamp(),
  };
}
function vote(uid, distance = 70, withPhoto = false) {
  return {
    userId: uid, voteType: 'HAZARD_RESOLVED', createdAt: serverTimestamp(),
    distanceFromHazardMeters: distance,
    proximityBand: distance <= 100 ? 'STRONG' : distance <= 300 ? 'NORMAL' : 'WEAK',
    isGpsValidated: true, photoUrl: '', hasPhotoEvidence: withPhoto,
    evidenceStorage: withPhoto ? 'firestore' : 'none',
    ...(withPhoto ? {
      evidenceValidationResult: {...validation, sceneMatchScore: .7},
      evidenceSha256: sha, evidencePerceptualHash: hash, evidenceSource: 'CAMERA', sceneMatchScore: .7,
    } : {}),
  };
}
async function create(db, uid = 'owner', id = 'report', overrides = {}, includePhoto = true) {
  const batch = writeBatch(db);
  batch.set(reportRef(db,id), {...report(uid,id), ...overrides});
  if (includePhoto) batch.set(doc(db,'hazard_reports',id,'evidence','photo'), photo(uid,id));
  return batch.commit();
}
async function seedVerified(id = 'report') {
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(reportRef(context.firestore(),id), {...report('owner',id), status:'Verified'});
  });
}
async function decide(db, status, id = 'report') {
  const batch = writeBatch(db);
  const repRef = reportRef(db, id);
  const repSnap = await getDoc(repRef);
  const prevStatus = repSnap.exists() ? repSnap.data().status : 'Pending Review';
  const prevHistory = repSnap.exists() && repSnap.data().statusHistory ? repSnap.data().statusHistory : [];
  const action = status === 'Verified' ? 'VERIFIED' :
                 status === 'Rejected' ? 'REJECTED' :
                 status === 'Resolved' ? 'MARKED_RESOLVED' : 'REVIEWED_KEEP_VERIFIED';

  batch.update(repRef, {
    status,
    reviewedBy: 'admin',
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    statusHistory: [
      ...prevHistory,
      { status, changedBy: 'admin', changedAt: Timestamp.now() },
    ],
  });
  batch.set(doc(db, 'hazard_reports', id, 'audit_logs', 'audit-' + id + '-' + status), {
    action,
    previousStatus: prevStatus,
    newStatus: status,
    performedBy: 'admin',
    performedAt: serverTimestamp(),
    note: 'Admin decision',
  });
  batch.set(doc(db, 'notifications', id + '-' + status), {
    notificationId: id + '-' + status,
    userId: 'owner',
    type: 'hazard_status',
    hazardId: id,
    title: 'Hazard report updated',
    message: status,
    isRead: false,
    createdAt: serverTimestamp(),
  });
  return batch.commit();
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-myheritage-safety',
    firestore: {
      host: '127.0.0.1',
      port: 8088,
      rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const uid of ['owner','other','third']) {
      await setDoc(doc(db,'travelers',uid),{role:'traveler',status:'active'});
    }
    await setDoc(doc(db,'travelers','disabled'),{role:'traveler',status:'disabled'});
    await setDoc(doc(db,'admins','admin'),{role:'admin',status:'active'});
  });
});

test('complete report → verify → confirmation → resolve workflow and owner notifications', async () => {
  const owner=dbFor('owner'), other=dbFor('other'), admin=dbFor('admin');
  await assertSucceeds(create(owner));
  assert.equal((await getDoc(reportRef(owner))).data().status,'Pending Review');
  assert.equal((await getDocs(query(collection(other,'hazard_reports'),where('status','==','Verified')))).size,0);
  await assertSucceeds(decide(admin,'Verified'));
  assert.equal((await getDocs(query(collection(other,'hazard_reports'),where('status','==','Verified')))).size,1);
  const batch=writeBatch(other);
  batch.set(voteRef(other,'other'),vote('other',70,true));
  batch.set(doc(other,'hazard_reports','report','votes','other','evidence','photo'),{...photo('other'),sceneMatchScore:.7});
  await assertSucceeds(batch.commit());
  assert.equal((await getDocs(collection(admin,'hazard_reports','report','votes'))).size,1);
  await assertSucceeds(decide(admin,'Resolved'));
  assert.equal((await getDocs(query(collection(other,'hazard_reports'),where('status','==','Verified')))).size,0);
  const notifications=await getDocs(query(collection(owner,'notifications'),where('userId','==','owner')));
  assert.equal(notifications.size,2);
  await assertSucceeds(updateDoc(doc(owner,'notifications','report-Resolved'),{isRead:true}));
  await assertFails(setDoc(voteRef(dbFor('third'),'third'),vote('third')));
});

test('reject removes pending report from active map and notifies owner', async () => {
  await create(dbFor('owner'));
  await assertSucceeds(decide(dbFor('admin'),'Rejected'));
  assert.equal((await getDoc(reportRef(dbFor('owner')))).data().status,'Rejected');
  await assertFails(decide(dbFor('admin'),'Verified'));
});

test('tourist cannot change official status or impersonate administrator', async () => {
  await create(dbFor('owner'));
  await assertFails(decide(dbFor('owner'),'Verified'));
  await assertFails(updateDoc(reportRef(dbFor('admin')), {
    status:'Verified',reviewedBy:'owner',reviewedAt:serverTimestamp(),updatedAt:serverTimestamp(),
  }));
});

test('unauthenticated, disabled and wrong-owner report submissions fail', async () => {
  await assertFails(create(env.unauthenticatedContext().firestore()));
  await assertFails(create(dbFor('disabled'),'disabled'));
  await assertFails(create(dbFor('other'),'owner'));
});

test('report and required photo must be atomic; invalid description/coordinates/status fail', async () => {
  const db=dbFor('owner');
  await assertFails(create(db,'owner','missing',{},false));
  for (const [id,overrides] of Object.entries({
    empty:{description:''},long:{description:'x'.repeat(501)},badlat:{latitude:91},
    badlon:{longitude:-181},published:{status:'Verified'},extra:{reviewedBy:'admin'},
  })) await assertFails(create(db,'owner',id,overrides));
  assert.equal((await getDocs(query(collection(db,'hazard_reports'),where('userId','==','owner')))).size,0);
});

test('atomic report photo mismatch rolls back both documents', async () => {
  const db=dbFor('owner'),batch=writeBatch(db);
  batch.set(reportRef(db),report('owner'));
  batch.set(doc(db,'hazard_reports','report','evidence','photo'),{...photo('owner'),sourceSha256:'b'.repeat(64)});
  await assertFails(batch.commit());
  await env.withSecurityRulesDisabled(async c => assert.equal((await getDoc(reportRef(c.firestore()))).exists(),false));
});

test('GPS proximity boundaries accepted and outside or negative distance denied', async () => {
  for (const [i,distance] of [70,100,250,300,450,500,500.01,800,-1].entries()) {
    const id='r'+i, db=dbFor('other');
    await seedVerified(id);
    const action=setDoc(voteRef(db,'other',id),vote('other',distance));
    if (distance>=0 && distance<=500) await assertSucceeds(action); else await assertFails(action);
  }
});

test('incorrect proximity band, identity, timestamp, extra fields and photo claims denied', async () => {
  await seedVerified();
  const db=dbFor('other');
  for (const overrides of [
    {proximityBand:'WEAK'},{userId:'owner'},{createdAt:Timestamp.fromMillis(0)},
    {reviewedBy:'admin'},{sceneMatchScore:1},{hasPhotoEvidence:true},
  ]) await assertFails(setDoc(voteRef(db,'other'),{...vote('other'),...overrides}));
});

test('one confirmation per user survives concurrent transaction attempts', async () => {
  await seedVerified();
  const db=dbFor('other');
  const submit=()=>runTransaction(db,async tx=>{
    const hazard=await tx.get(reportRef(db));
    const existing=await tx.get(voteRef(db,'other'));
    if (hazard.data().status!=='Verified'||existing.exists()) throw new Error('closed or duplicate');
    tx.set(voteRef(db,'other'),vote('other'));
  });
  const outcomes=await Promise.allSettled([submit(),submit()]);
  assert.equal(outcomes.filter(x=>x.status==='fulfilled').length,1);
  assert.equal((await getDocs(collection(dbFor('admin'),'hazard_reports','report','votes'))).size,1);
  await assertFails(updateDoc(voteRef(db,'other'),{voteType:'HAZARD_EXISTS'}));
});

test('pending/rejected/resolved reports cannot receive confirmations', async () => {
  for(const status of ['Pending Review','Rejected','Resolved']) {
    await env.withSecurityRulesDisabled(c=>setDoc(reportRef(c.firestore()),{...report('owner'),status}));
    await assertFails(setDoc(voteRef(dbFor('other'),'other'),vote('other')));
  }
});

test('orphan vote photo and oversize photo are denied', async () => {
  await seedVerified();
  const db=dbFor('other');
  await assertFails(setDoc(doc(db,'hazard_reports','report','votes','other','evidence','photo'),photo('other')));
  const batch=writeBatch(db);
  batch.set(voteRef(db,'other'),vote('other',70,true));
  batch.set(doc(db,'hazard_reports','report','votes','other','evidence','photo'),{
    ...photo('other'),imageBytes:Bytes.fromUint8Array(new Uint8Array(400*1024+1)),byteLength:400*1024+1,
  });
  await assertFails(batch.commit());
});

test('own history collection-group lookup works; other users history is denied', async () => {
  await seedVerified();
  const db=dbFor('other');
  await setDoc(voteRef(db,'other'),vote('other'));
  await assertSucceeds(getDocs(query(collectionGroup(db,'votes'),where('userId','==','other'))));
  await assertFails(getDocs(query(collectionGroup(db,'votes'),where('userId','==','owner'))));
});

test('pending report private to owner/admin and notifications private to recipient', async () => {
  await create(dbFor('owner'));
  await assertFails(getDoc(reportRef(dbFor('other'))));
  await assertSucceeds(getDoc(reportRef(dbFor('admin'))));
  await decide(dbFor('admin'),'Verified');
  await assertFails(getDoc(doc(dbFor('other'),'notifications','report-Verified')));
});

test('duplicate or invalid evidence validation is denied', async () => {
  for (const [i,changes] of [{duplicateDetected:true},{isValid:false},{qualityScore:2},{semanticValidationAvailable:true}].entries()) {
    await assertFails(create(dbFor('owner'),'owner','bad'+i,{
      evidenceValidationResult:{...validation,...changes},
    }));
  }
});

test('tourist cannot inject AI analysis fields on vote creation or vote update', async () => {
  await seedVerified('ai_report');
  const tourist = dbFor('other');

  // A & D: Tourist can create a normal valid vote with NO AI fields
  await assertSucceeds(setDoc(voteRef(tourist, 'other', 'ai_report'), vote('other')));

  // C: Tourist CANNOT update an existing vote to inject trusted AI fields
  await assertFails(updateDoc(voteRef(tourist, 'other', 'ai_report'), {
    aiAnalysisStatus: 'COMPLETE',
    aiEvidenceWeightMultiplier: 1.10,
  }));

  // B: Tourist CANNOT create a new vote with trusted AI fields
  await seedVerified('ai_report_2');
  const aiFieldsToTest = [
    { aiAnalysisStatus: 'COMPLETE' },
    { aiEvidenceWeightMultiplier: 1.10 },
    { aiAgreement: 'SUPPORTS_VOTE' },
    { aiSceneMatchScore: 0.90 },
    { aiHazardRelevanceScore: 0.95 },
    { aiConditionAssessment: 'HAZARD_STILL_PRESENT' },
    { aiConditionConfidence: 0.85 },
    { aiAnalysisSummary: 'Injected summary' },
    { aiAnalysisCompletedAt: Timestamp.now() },
    { aiAnalysisFailureReason: 'NONE' },
    { aiSyntheticImageRisk: 'LOW' },
    { aiSyntheticImageConfidence: 0.95 },
    { aiSyntheticImageSummary: 'Injected synthetic summary' },
    // Legacy aliases
    { aiStatus: 'COMPLETE' },
    { aiMultiplier: 1.10 },
    { aiConfidence: 0.90 },
    { aiReasoning: 'Legacy reasoning' },
    { aiSceneMatch: 'MATCH' },
    { aiHazardRelevance: 'RELEVANT' },
    { aiCondition: 'HAZARD_STILL_PRESENT' },
    { aiAnalyzedAt: Timestamp.now() },
    { aiModelVersion: 'gemini-1.5' },
    { aiOriginalPhotoUrl: 'https://example.com/orig.jpg' },
    { aiCommunityPhotoUrl: 'https://example.com/comm.jpg' },
  ];

  for (const aiField of aiFieldsToTest) {
    await assertFails(
      setDoc(voteRef(tourist, 'other', 'ai_report_2'), {
        ...vote('other'),
        ...aiField,
      })
    );
  }
});

test('administrator client can read AI results but CANNOT modify server-owned AI fields', async () => {
  await seedVerified('ai_admin_report');
  const admin = dbFor('admin');

  // Cloud Function writes AI fields via Admin SDK (simulated via withSecurityRulesDisabled)
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(voteRef(db, 'other', 'ai_admin_report'), {
      ...vote('other'),
      aiAnalysisStatus: 'COMPLETE',
      aiAgreement: 'SUPPORTS_VOTE',
      aiEvidenceWeightMultiplier: 1.10,
      aiSceneMatchScore: 0.88,
      aiHazardRelevanceScore: 0.92,
      aiConditionAssessment: 'HAZARD_STILL_PRESENT',
      aiConditionConfidence: 0.85,
      aiAnalysisSummary: 'Scene matches and hazard is clearly visible.',
      aiSyntheticImageRisk: 'LOW',
      aiSyntheticImageConfidence: 0.90,
      aiSyntheticImageSummary: 'No strong synthetic indicators were identified.',
      aiAnalysisCompletedAt: Timestamp.now(),
    });
  });

  // D: Administrator client CAN read vote containing server-computed AI results
  const snap = await assertSucceeds(getDoc(voteRef(admin, 'other', 'ai_admin_report')));
  assert.equal(snap.data().aiAgreement, 'SUPPORTS_VOTE');
  assert.equal(snap.data().aiEvidenceWeightMultiplier, 1.10);
  assert.equal(snap.data().aiAnalysisStatus, 'COMPLETE');
  assert.equal(snap.data().aiSyntheticImageRisk, 'LOW');
  assert.equal(snap.data().aiSyntheticImageConfidence, 0.90);
  assert.equal(snap.data().aiSyntheticImageSummary, 'No strong synthetic indicators were identified.');

  // E: Administrator CLIENT attempts to manually modify aiAgreement → FAILS
  await assertFails(updateDoc(voteRef(admin, 'other', 'ai_admin_report'), {
    aiAgreement: 'CONFLICTS_WITH_VOTE',
  }));

  // F: Administrator CLIENT attempts to manually modify aiEvidenceWeightMultiplier → FAILS
  await assertFails(updateDoc(voteRef(admin, 'other', 'ai_admin_report'), {
    aiEvidenceWeightMultiplier: 0.90,
  }));

  // G: Administrator CLIENT attempts to modify other server-owned AI fields → FAILS
  const forbiddenAdminPatches = [
    { aiAnalysisStatus: 'FAILED' },
    { aiSceneMatchScore: 0.50 },
    { aiHazardRelevanceScore: 0.50 },
    { aiConditionAssessment: 'APPEARS_RESOLVED' },
    { aiConditionConfidence: 0.50 },
    { aiAnalysisSummary: 'Manually tampered summary' },
    { aiAnalysisCompletedAt: Timestamp.now() },
    { aiAnalysisFailureReason: 'TAMPERED' },
    { aiSyntheticImageRisk: 'ELEVATED' },
    { aiSyntheticImageConfidence: 0.10 },
    { aiSyntheticImageSummary: 'Admin tampered synthetic summary' },
    { aiStatus: 'COMPLETE' },
    { aiMultiplier: 0.90 },
    { aiConfidence: 0.50 },
    { aiReasoning: 'Tampered reasoning' },
    { aiSceneMatch: 'MATCH' },
    { aiHazardRelevance: 'RELEVANT' },
    { aiCondition: 'APPEARS_RESOLVED' },
    { aiAnalyzedAt: Timestamp.now() },
    { aiModelVersion: 'tampered' },
    { aiOriginalPhotoUrl: 'https://example.com/tampered.jpg' },
    { aiCommunityPhotoUrl: 'https://example.com/tampered.jpg' },
  ];
  for (const patch of forbiddenAdminPatches) {
    await assertFails(updateDoc(voteRef(admin, 'other', 'ai_admin_report'), patch));
  }

  // H: Legitimate Admin hazard management actions (Verify, Resolve, notifications) still succeed
  await assertSucceeds(decide(admin, 'Resolved', 'ai_admin_report'));
});

test('Step 11: Tourist and Administrator clients cannot create or modify synthetic image risk fields', async () => {
  await seedVerified('synthetic_security_hazard');
  const tourist = dbFor('other');
  const admin = dbFor('admin');

  // 1. Tourist cannot create vote containing aiSyntheticImageRisk
  await assertFails(setDoc(voteRef(tourist, 'other', 'synthetic_security_hazard'), {
    ...vote('other'),
    aiSyntheticImageRisk: 'LOW',
  }));

  // 2. Tourist cannot create vote containing aiSyntheticImageConfidence
  await assertFails(setDoc(voteRef(tourist, 'other', 'synthetic_security_hazard'), {
    ...vote('other'),
    aiSyntheticImageConfidence: 0.90,
  }));

  // 3. Tourist cannot create vote containing aiSyntheticImageSummary
  await assertFails(setDoc(voteRef(tourist, 'other', 'synthetic_security_hazard'), {
    ...vote('other'),
    aiSyntheticImageSummary: 'Tourist forged summary',
  }));

  // 4. Valid vote created by tourist succeeds
  await assertSucceeds(setDoc(voteRef(tourist, 'other', 'synthetic_security_hazard'), vote('other')));

  // 5. Tourist cannot update vote to inject synthetic fields
  await assertFails(updateDoc(voteRef(tourist, 'other', 'synthetic_security_hazard'), {
    aiSyntheticImageRisk: 'LOW',
  }));
  await assertFails(updateDoc(voteRef(tourist, 'other', 'synthetic_security_hazard'), {
    aiSyntheticImageConfidence: 0.85,
  }));
  await assertFails(updateDoc(voteRef(tourist, 'other', 'synthetic_security_hazard'), {
    aiSyntheticImageSummary: 'Forged summary on update',
  }));

  // 6. Admin SDK simulates Cloud Function writing synthetic fields
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await updateDoc(voteRef(db, 'other', 'synthetic_security_hazard'), {
      aiSyntheticImageRisk: 'ELEVATED',
      aiSyntheticImageConfidence: 0.88,
      aiSyntheticImageSummary: 'Multiple geometric distortions detected.',
    });
  });

  // 7. Administrator can read the synthetic fields
  const snap = await assertSucceeds(getDoc(voteRef(admin, 'other', 'synthetic_security_hazard')));
  assert.equal(snap.data().aiSyntheticImageRisk, 'ELEVATED');
  assert.equal(snap.data().aiSyntheticImageConfidence, 0.88);
  assert.equal(snap.data().aiSyntheticImageSummary, 'Multiple geometric distortions detected.');

  // 8. Administrator client cannot modify synthetic fields
  await assertFails(updateDoc(voteRef(admin, 'other', 'synthetic_security_hazard'), {
    aiSyntheticImageRisk: 'LOW',
  }));
  await assertFails(updateDoc(voteRef(admin, 'other', 'synthetic_security_hazard'), {
    aiSyntheticImageConfidence: 0.10,
  }));
  await assertFails(updateDoc(voteRef(admin, 'other', 'synthetic_security_hazard'), {
    aiSyntheticImageSummary: 'Admin modified summary',
  }));
});

test('tourist and administrator clients cannot forge Step 8 server fields', async () => {
  await seedVerified('server_fields');
  const tourist = dbFor('other'), admin = dbFor('admin');
  const forbiddenVoteFields = [
    {serverValidationStatus: 'VALID'},
    {serverValidatedAt: Timestamp.now()},
    {serverValidationReasons: []},
  ];
  for (const fields of forbiddenVoteFields) {
    await assertFails(setDoc(voteRef(tourist, 'other', 'server_fields'), {
      ...vote('other'), ...fields,
    }));
  }

  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(voteRef(db, 'other', 'server_fields'), {
      ...vote('other'), serverValidationStatus: 'VALID',
      serverValidatedAt: Timestamp.now(), serverValidationReasons: [],
    });
    await updateDoc(reportRef(db, 'server_fields'), {
      serverConfidence: {
        formulaVersion: 'safety-confidence-v1', calculatedAt: Timestamp.now(),
        confidencePercent: 75, confidenceLevel: 'HIGH',
      },
    });
  });

  await assertFails(updateDoc(voteRef(admin, 'other', 'server_fields'), {
    serverValidationStatus: 'INVALID',
  }));
  await assertFails(updateDoc(reportRef(admin, 'server_fields'), {
    serverConfidence: {formulaVersion: 'forged', confidencePercent: 100},
  }));
  await assertFails(updateDoc(reportRef(tourist, 'server_fields'), {
    serverConfidence: {formulaVersion: 'forged', confidencePercent: 100},
  }));

  const reportSnap = await assertSucceeds(getDoc(reportRef(admin, 'server_fields')));
  assert.equal(reportSnap.data().serverConfidence.formulaVersion, 'safety-confidence-v1');
  const voteSnap = await assertSucceeds(getDoc(voteRef(admin, 'other', 'server_fields')));
  assert.equal(voteSnap.data().serverValidationStatus, 'VALID');
});

test('existing AI protections and Admin lifecycle updates preserve serverConfidence', async () => {
  await seedVerified('preserve_server_summary');
  await env.withSecurityRulesDisabled(async context => {
    await updateDoc(reportRef(context.firestore(), 'preserve_server_summary'), {
      serverConfidence: {
        formulaVersion: 'safety-confidence-v1', calculatedAt: Timestamp.now(),
        confidencePercent: 60, confidenceLevel: 'MEDIUM',
      },
    });
  });
  await assertSucceeds(decide(dbFor('admin'), 'Resolved', 'preserve_server_summary'));
  const result = await getDoc(reportRef(dbFor('admin'), 'preserve_server_summary'));
  assert.equal(result.data().serverConfidence.confidencePercent, 60);
});

test('Step 9: audit_logs subcollection security and Keep Verified lifecycle action', async () => {
  const admin = dbFor('admin'), tourist = dbFor('owner');
  await seedVerified('audit_hazard');

  const auditLogRef = (db, hazardId, auditId) =>
    doc(db, 'hazard_reports', hazardId, 'audit_logs', auditId);

  // 1. Admin CANNOT write a standalone audit log entry without corresponding hazard update
  await assertFails(setDoc(auditLogRef(admin, 'audit_hazard', 'log1'), {
    action: 'REVIEWED_KEEP_VERIFIED',
    previousStatus: 'Verified',
    newStatus: 'Verified',
    performedBy: 'admin',
    performedByName: 'Admin Sherman',
    performedAt: serverTimestamp(),
    note: 'Standalone uncoupled audit entry',
  }));

  // 2. Admin CAN perform Keep Verified update on hazard_report with atomic audit log
  const batch = writeBatch(admin);
  batch.update(reportRef(admin, 'audit_hazard'), {
    reviewedBy: 'admin',
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batch.set(auditLogRef(admin, 'audit_hazard', 'log1'), {
    action: 'REVIEWED_KEEP_VERIFIED',
    previousStatus: 'Verified',
    newStatus: 'Verified',
    performedBy: 'admin',
    performedByName: 'Admin Sherman',
    performedAt: serverTimestamp(),
    note: 'Atomic review action',
  });
  await assertSucceeds(batch.commit());

  // 3. Admin can read audit log
  const adminReadSnap = await assertSucceeds(getDoc(auditLogRef(admin, 'audit_hazard', 'log1')));
  assert.equal(adminReadSnap.data().action, 'REVIEWED_KEEP_VERIFIED');

  // 4. Tourist CANNOT read audit log
  await assertFails(getDoc(auditLogRef(tourist, 'audit_hazard', 'log1')));

  // 5. Tourist CANNOT create audit log
  await assertFails(setDoc(auditLogRef(tourist, 'audit_hazard', 'log2'), {
    action: 'REVIEWED_KEEP_VERIFIED',
    previousStatus: 'Verified',
    newStatus: 'Verified',
    performedBy: 'owner',
    performedAt: serverTimestamp(),
    note: 'Unauthorized tourist audit entry',
  }));

  // 6. Nobody can update or delete audit log
  await assertFails(updateDoc(auditLogRef(admin, 'audit_hazard', 'log1'), {
    note: 'Tampered note',
  }));
});

test('Step 15 Fix 2: Tourist cannot seed fake status history', async () => {
  const owner = dbFor('owner');
  // a) Multiple statusHistory items fails
  await assertFails(create(owner, 'owner', 'fake-hist-1', {
    statusHistory: [
      { status: 'Pending Review', changedBy: 'owner', changedAt: Timestamp.now() },
      { status: 'Verified', changedBy: 'admin', changedAt: Timestamp.now() },
    ],
  }));
  // b) statusHistory with status == 'Verified' fails
  await assertFails(create(owner, 'owner', 'fake-hist-2', {
    statusHistory: [
      { status: 'Verified', changedBy: 'owner', changedAt: Timestamp.now() },
    ],
  }));
  // c) statusHistory with changedBy != request.auth.uid fails
  await assertFails(create(owner, 'owner', 'fake-hist-3', {
    statusHistory: [
      { status: 'Pending Review', changedBy: 'admin', changedAt: Timestamp.now() },
    ],
  }));
});

test('Step 15 Fix 2: Standalone fake audit and audit identity enforcement', async () => {
  const admin = dbFor('admin');
  await seedVerified('audit-test-hazard');
  const auditRef = (id) => doc(admin, 'hazard_reports', 'audit-test-hazard', 'audit_logs', id);

  // Standalone audit log without updating hazard in batch fails
  await assertFails(setDoc(auditRef('fake-standalone'), {
    action: 'VERIFIED',
    previousStatus: 'Pending Review',
    newStatus: 'Verified',
    performedBy: 'admin',
    performedAt: serverTimestamp(),
    note: 'Standalone fake verification',
  }));

  // Mismatched transition (action doesn't match hazard state) fails
  const badBatch = writeBatch(admin);
  badBatch.update(reportRef(admin, 'audit-test-hazard'), {
    reviewedBy: 'admin',
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  badBatch.set(auditRef('mismatched-log'), {
    action: 'VERIFIED', // hazard is already Verified, not Pending Review
    previousStatus: 'Pending Review',
    newStatus: 'Verified',
    performedBy: 'admin',
    performedAt: serverTimestamp(),
    note: 'Mismatched action',
  });
  await assertFails(badBatch.commit());

  // Wrong performedBy fails
  const wrongUidBatch = writeBatch(admin);
  wrongUidBatch.update(reportRef(admin, 'audit-test-hazard'), {
    reviewedBy: 'admin',
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  wrongUidBatch.set(auditRef('wrong-uid-log'), {
    action: 'REVIEWED_KEEP_VERIFIED',
    previousStatus: 'Verified',
    newStatus: 'Verified',
    performedBy: 'other_admin',
    performedAt: serverTimestamp(),
    note: 'Impersonating another admin',
  });
  await assertFails(wrongUidBatch.commit());
});

test('Step 15 Fix 1: Unified ruleset rejects unknown collections and protects teammate modules', async () => {
  const tourist = dbFor('owner');
  const admin = dbFor('admin');

  // Wildcard / arbitrary unknown path write fails
  await assertFails(setDoc(doc(tourist, 'secret_records', 'doc1'), { secret: 'data' }));
  await assertFails(setDoc(doc(admin, 'secret_records', 'doc1'), { secret: 'data' }));
  await assertFails(getDoc(doc(tourist, 'secret_records', 'doc1')));

  // Teammates' valid paths succeed:
  // Public places read
  await assertSucceeds(getDoc(doc(tourist, 'places', 'place1')));
  // Cultural task submission
  await assertSucceeds(setDoc(doc(tourist, 'cultural_tasks', 't1', 'task_submissions', 'sub1'), {
    userId: 'owner',
    status: 'submitted',
  }));
  // Unauthorized user cannot forge another user's submission
  await assertFails(setDoc(doc(tourist, 'cultural_tasks', 't1', 'task_submissions', 'sub2'), {
    userId: 'other_user',
    status: 'submitted',
  }));
});

// =========================================================================
// REGRESSION TESTS: BUGS 2 & 3 (Tests 1 - 15)
// =========================================================================

test('Regression Tests 1-4: Audit logs read permissions (Admin, Tourist, Vendor, Unauthenticated)', async () => {
  const admin = dbFor('admin');
  const tourist = dbFor('owner');
  const vendor = dbFor('vendor_user');
  const unauth = env.unauthenticatedContext().firestore();

  // Setup vendor and an audit log under hazard_reports/reg_audit_hazard
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'vendors', 'vendor_user'), { role: 'vendor', status: 'active' });
    await setDoc(reportRef(db, 'reg_audit_hazard'), report('owner', 'reg_audit_hazard'));
    await setDoc(doc(db, 'hazard_reports', 'reg_audit_hazard', 'audit_logs', 'log1'), {
      action: 'VERIFIED',
      previousStatus: 'Pending Review',
      newStatus: 'Verified',
      performedBy: 'admin',
      performedByName: 'Admin Sherman',
      performedAt: serverTimestamp(),
      note: 'Verified during audit',
    });
  });

  const auditCol = (db) => collection(db, 'hazard_reports', 'reg_audit_hazard', 'audit_logs');
  const auditDocRef = (db) => doc(db, 'hazard_reports', 'reg_audit_hazard', 'audit_logs', 'log1');

  // 1. Admin reads audit_logs successfully
  const adminSnap = await assertSucceeds(getDocs(auditCol(admin)));
  assert.equal(adminSnap.size, 1);
  const adminDocSnap = await assertSucceeds(getDoc(auditDocRef(admin)));
  assert.equal(adminDocSnap.data().action, 'VERIFIED');

  // 2. Tourist cannot read audit_logs
  await assertFails(getDocs(auditCol(tourist)));
  await assertFails(getDoc(auditDocRef(tourist)));

  // 3. Vendor cannot read audit_logs
  await assertFails(getDocs(auditCol(vendor)));
  await assertFails(getDoc(auditDocRef(vendor)));

  // 4. Unauthenticated user cannot read audit_logs
  await assertFails(getDocs(auditCol(unauth)));
  await assertFails(getDoc(auditDocRef(unauth)));
});

test('Regression Tests 5-6: Verify atomic batch/transaction succeeds on legacy report without statusHistory and report with existing statusHistory', async () => {
  const admin = dbFor('admin');

  // 5. Verify atomic batch succeeds on legacy report without statusHistory
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    const legacy = report('owner', 'legacy_report');
    delete legacy.statusHistory;
    await setDoc(reportRef(db, 'legacy_report'), legacy);
  });

  const batchLegacy = writeBatch(admin);
  batchLegacy.update(reportRef(admin, 'legacy_report'), {
    status: 'Verified',
    reviewedBy: 'admin',
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    statusHistory: [
      { status: 'Verified', changedBy: 'admin', changedAt: Timestamp.now() }
    ],
  });
  batchLegacy.set(doc(admin, 'hazard_reports', 'legacy_report', 'audit_logs', 'audit-legacy'), {
    action: 'VERIFIED',
    previousStatus: 'Pending Review',
    newStatus: 'Verified',
    performedBy: 'admin',
    performedByName: 'Admin Sherman',
    performedAt: serverTimestamp(),
    note: 'Verified legacy hazard',
  });
  batchLegacy.set(doc(admin, 'notifications', 'legacy_report-Verified'), {
    notificationId: 'legacy_report-Verified',
    userId: 'owner',
    type: 'hazard_status',
    hazardId: 'legacy_report',
    title: 'Hazard report updated',
    message: 'Verified',
    isRead: false,
    createdAt: serverTimestamp(),
  });
  await assertSucceeds(batchLegacy.commit());
  const updatedLegacy = await getDoc(reportRef(admin, 'legacy_report'));
  assert.equal(updatedLegacy.data().status, 'Verified');
  assert.equal(updatedLegacy.data().statusHistory.length, 1);

  // 6. Verify atomic batch succeeds on report with existing statusHistory
  await create(dbFor('owner'), 'owner', 'normal_report');
  const batchNormal = writeBatch(admin);
  batchNormal.update(reportRef(admin, 'normal_report'), {
    status: 'Verified',
    reviewedBy: 'admin',
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    statusHistory: [
      { status: 'Pending Review', changedBy: 'owner', changedAt: Timestamp.now() },
      { status: 'Verified', changedBy: 'admin', changedAt: Timestamp.now() }
    ],
  });
  batchNormal.set(doc(admin, 'hazard_reports', 'normal_report', 'audit_logs', 'audit-normal'), {
    action: 'VERIFIED',
    previousStatus: 'Pending Review',
    newStatus: 'Verified',
    performedBy: 'admin',
    performedByName: 'Admin Sherman',
    performedAt: serverTimestamp(),
    note: 'Verified standard hazard',
  });
  batchNormal.set(doc(admin, 'notifications', 'normal_report-Verified'), {
    notificationId: 'normal_report-Verified',
    userId: 'owner',
    type: 'hazard_status',
    hazardId: 'normal_report',
    title: 'Hazard report updated',
    message: 'Verified',
    isRead: false,
    createdAt: serverTimestamp(),
  });
  await assertSucceeds(batchNormal.commit());
  const updatedNormal = await getDoc(reportRef(admin, 'normal_report'));
  assert.equal(updatedNormal.data().status, 'Verified');
  assert.equal(updatedNormal.data().statusHistory.length, 2);
});

test('Regression Tests 7-9: Verify fails if audit_log omitted, action is wrong, or performedBy != auth.uid', async () => {
  const admin = dbFor('admin');
  await create(dbFor('owner'), 'owner', 'guard_report');

  // 7. Verify audit log creation fails if hazard update is omitted (standalone audit log cannot verify)
  const auditAloneRef = doc(admin, 'hazard_reports', 'guard_report', 'audit_logs', 'audit-alone');
  await assertFails(setDoc(auditAloneRef, {
    action: 'VERIFIED',
    previousStatus: 'Pending Review',
    newStatus: 'Verified',
    performedBy: 'admin',
    performedByName: 'Admin Sherman',
    performedAt: serverTimestamp(),
    note: 'Standalone audit without hazard update',
  }));

  // 8. Verify fails if audit action is wrong (e.g. MARKED_RESOLVED when verifying Pending Review)
  const batchWrongAction = writeBatch(admin);
  batchWrongAction.update(reportRef(admin, 'guard_report'), {
    status: 'Verified',
    reviewedBy: 'admin',
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    statusHistory: [
      { status: 'Pending Review', changedBy: 'owner', changedAt: Timestamp.now() },
      { status: 'Verified', changedBy: 'admin', changedAt: Timestamp.now() }
    ],
  });
  batchWrongAction.set(doc(admin, 'hazard_reports', 'guard_report', 'audit_logs', 'audit-wrong-act'), {
    action: 'MARKED_RESOLVED', // Invalid action for Pending Review -> Verified
    previousStatus: 'Pending Review',
    newStatus: 'Verified',
    performedBy: 'admin',
    performedByName: 'Admin Sherman',
    performedAt: serverTimestamp(),
    note: 'Wrong action test',
  });
  batchWrongAction.set(doc(admin, 'notifications', 'guard_report-Verified-2'), {
    notificationId: 'guard_report-Verified-2',
    userId: 'owner',
    type: 'hazard_status',
    hazardId: 'guard_report',
    title: 'Hazard report updated',
    message: 'Verified',
    isRead: false,
    createdAt: serverTimestamp(),
  });
  await assertFails(batchWrongAction.commit());

  // 9. Verify fails if audit performedBy != auth.uid
  const batchWrongUid = writeBatch(admin);
  batchWrongUid.update(reportRef(admin, 'guard_report'), {
    status: 'Verified',
    reviewedBy: 'admin',
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    statusHistory: [
      { status: 'Pending Review', changedBy: 'owner', changedAt: Timestamp.now() },
      { status: 'Verified', changedBy: 'admin', changedAt: Timestamp.now() }
    ],
  });
  batchWrongUid.set(doc(admin, 'hazard_reports', 'guard_report', 'audit_logs', 'audit-wrong-uid'), {
    action: 'VERIFIED',
    previousStatus: 'Pending Review',
    newStatus: 'Verified',
    performedBy: 'impostor_admin', // Mismatched auth.uid
    performedByName: 'Impostor',
    performedAt: serverTimestamp(),
    note: 'Wrong UID test',
  });
  batchWrongUid.set(doc(admin, 'notifications', 'guard_report-Verified-3'), {
    notificationId: 'guard_report-Verified-3',
    userId: 'owner',
    type: 'hazard_status',
    hazardId: 'guard_report',
    title: 'Hazard report updated',
    message: 'Verified',
    isRead: false,
    createdAt: serverTimestamp(),
  });
  await assertFails(batchWrongUid.commit());
});

test('Regression Tests 10-12: Verify fails if already Rejected, already Resolved, or initiated by Tourist', async () => {
  const admin = dbFor('admin');
  const tourist = dbFor('owner');

  // Seed Rejected report
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(reportRef(db, 'rejected_report'), { ...report('owner', 'rejected_report'), status: 'Rejected' });
    await setDoc(reportRef(db, 'resolved_report'), { ...report('owner', 'resolved_report'), status: 'Resolved' });
  });

  // 10. Verify fails if report already Rejected
  const batchFromRejected = writeBatch(admin);
  batchFromRejected.update(reportRef(admin, 'rejected_report'), {
    status: 'Verified',
    reviewedBy: 'admin',
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    statusHistory: [
      { status: 'Pending Review', changedBy: 'owner', changedAt: Timestamp.now() },
      { status: 'Rejected', changedBy: 'admin', changedAt: Timestamp.now() },
      { status: 'Verified', changedBy: 'admin', changedAt: Timestamp.now() }
    ],
  });
  batchFromRejected.set(doc(admin, 'hazard_reports', 'rejected_report', 'audit_logs', 'audit-rej-to-ver'), {
    action: 'VERIFIED',
    previousStatus: 'Rejected',
    newStatus: 'Verified',
    performedBy: 'admin',
    performedByName: 'Admin Sherman',
    performedAt: serverTimestamp(),
    note: 'Trying to verify rejected',
  });
  await assertFails(batchFromRejected.commit());

  // 11. Verify fails if report already Resolved
  const batchFromResolved = writeBatch(admin);
  batchFromResolved.update(reportRef(admin, 'resolved_report'), {
    status: 'Verified',
    reviewedBy: 'admin',
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    statusHistory: [
      { status: 'Pending Review', changedBy: 'owner', changedAt: Timestamp.now() },
      { status: 'Resolved', changedBy: 'admin', changedAt: Timestamp.now() },
      { status: 'Verified', changedBy: 'admin', changedAt: Timestamp.now() }
    ],
  });
  batchFromResolved.set(doc(admin, 'hazard_reports', 'resolved_report', 'audit_logs', 'audit-res-to-ver'), {
    action: 'VERIFIED',
    previousStatus: 'Resolved',
    newStatus: 'Verified',
    performedBy: 'admin',
    performedByName: 'Admin Sherman',
    performedAt: serverTimestamp(),
    note: 'Trying to verify resolved',
  });
  await assertFails(batchFromResolved.commit());

  // 12. Tourist cannot execute verify transition
  await create(dbFor('owner'), 'owner', 'tourist_verify_target');
  const batchTouristVerify = writeBatch(tourist);
  batchTouristVerify.update(reportRef(tourist, 'tourist_verify_target'), {
    status: 'Verified',
    reviewedBy: 'owner',
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    statusHistory: [
      { status: 'Pending Review', changedBy: 'owner', changedAt: Timestamp.now() },
      { status: 'Verified', changedBy: 'owner', changedAt: Timestamp.now() }
    ],
  });
  batchTouristVerify.set(doc(tourist, 'hazard_reports', 'tourist_verify_target', 'audit_logs', 'audit-tourist'), {
    action: 'VERIFIED',
    previousStatus: 'Pending Review',
    newStatus: 'Verified',
    performedBy: 'owner',
    performedByName: 'Tourist Owner',
    performedAt: serverTimestamp(),
    note: 'Unauthorized verify',
  });
  await assertFails(batchTouristVerify.commit());
});

test('Regression Tests 13-15: Admin lifecycle transitions (Pending->Rejected, Verified->Keep Verified, Verified->Resolved)', async () => {
  const admin = dbFor('admin');

  // 13. Admin can execute Pending -> Rejected transition with REJECTED audit log
  await create(dbFor('owner'), 'owner', 'trans_pending_rej');
  const batchRej = writeBatch(admin);
  batchRej.update(reportRef(admin, 'trans_pending_rej'), {
    status: 'Rejected',
    reviewedBy: 'admin',
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    statusHistory: [
      { status: 'Pending Review', changedBy: 'owner', changedAt: Timestamp.now() },
      { status: 'Rejected', changedBy: 'admin', changedAt: Timestamp.now() }
    ],
  });
  batchRej.set(doc(admin, 'hazard_reports', 'trans_pending_rej', 'audit_logs', 'audit-rej'), {
    action: 'REJECTED',
    previousStatus: 'Pending Review',
    newStatus: 'Rejected',
    performedBy: 'admin',
    performedByName: 'Admin Sherman',
    performedAt: serverTimestamp(),
    note: 'Rejecting invalid report',
  });
  batchRej.set(doc(admin, 'notifications', 'trans_pending_rej-Rejected'), {
    notificationId: 'trans_pending_rej-Rejected',
    userId: 'owner',
    type: 'hazard_status',
    hazardId: 'trans_pending_rej',
    title: 'Hazard report updated',
    message: 'Rejected',
    isRead: false,
    createdAt: serverTimestamp(),
  });
  await assertSucceeds(batchRej.commit());
  const rejectedSnap = await getDoc(reportRef(admin, 'trans_pending_rej'));
  assert.equal(rejectedSnap.data().status, 'Rejected');

  // 14. Admin can execute Verified -> Keep Verified action with REVIEWED_KEEP_VERIFIED audit log
  await seedVerified('trans_keep_ver');
  const batchKeep = writeBatch(admin);
  batchKeep.update(reportRef(admin, 'trans_keep_ver'), {
    reviewedBy: 'admin',
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batchKeep.set(doc(admin, 'hazard_reports', 'trans_keep_ver', 'audit_logs', 'audit-keep'), {
    action: 'REVIEWED_KEEP_VERIFIED',
    previousStatus: 'Verified',
    newStatus: 'Verified',
    performedBy: 'admin',
    performedByName: 'Admin Sherman',
    performedAt: serverTimestamp(),
    note: 'Keep verified after review',
  });
  await assertSucceeds(batchKeep.commit());
  const keptSnap = await getDoc(reportRef(admin, 'trans_keep_ver'));
  assert.equal(keptSnap.data().status, 'Verified');

  // 15. Admin can execute Verified -> Resolved transition with MARKED_RESOLVED audit log
  await seedVerified('trans_to_res');
  const batchRes = writeBatch(admin);
  batchRes.update(reportRef(admin, 'trans_to_res'), {
    status: 'Resolved',
    reviewedBy: 'admin',
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    statusHistory: [
      { status: 'Pending Review', changedBy: 'owner', changedAt: Timestamp.now() },
      { status: 'Resolved', changedBy: 'admin', changedAt: Timestamp.now() }
    ],
  });
  batchRes.set(doc(admin, 'hazard_reports', 'trans_to_res', 'audit_logs', 'audit-res'), {
    action: 'MARKED_RESOLVED',
    previousStatus: 'Verified',
    newStatus: 'Resolved',
    performedBy: 'admin',
    performedByName: 'Admin Sherman',
    performedAt: serverTimestamp(),
    note: 'Hazard cleared, marking resolved',
  });
  batchRes.set(doc(admin, 'notifications', 'trans_to_res-Resolved'), {
    notificationId: 'trans_to_res-Resolved',
    userId: 'owner',
    type: 'hazard_status',
    hazardId: 'trans_to_res',
    title: 'Hazard report updated',
    message: 'Resolved',
    isRead: false,
    createdAt: serverTimestamp(),
  });
  await assertSucceeds(batchRes.commit());
  const resolvedSnap = await getDoc(reportRef(admin, 'trans_to_res'));
  assert.equal(resolvedSnap.data().status, 'Resolved');
});
