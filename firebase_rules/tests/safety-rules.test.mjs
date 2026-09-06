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
  batch.update(reportRef(db,id), {
    status, reviewedBy: 'admin', reviewedAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  batch.set(doc(db,'notifications',id+'-'+status), {
    notificationId:id+'-'+status, userId:'owner', type:'hazard_status', hazardId:id,
    title:'Hazard report updated', message:status, isRead:false, createdAt:serverTimestamp(),
  });
  return batch.commit();
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-myheritage-safety',
    firestore: {host:'127.0.0.1', port:8088,
      rules: await readFile(new URL('../safety_module.firestore.rules', import.meta.url),'utf8')},
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
      aiAnalysisCompletedAt: Timestamp.now(),
    });
  });

  // D: Administrator client CAN read vote containing server-computed AI results
  const snap = await assertSucceeds(getDoc(voteRef(admin, 'other', 'ai_admin_report')));
  assert.equal(snap.data().aiAgreement, 'SUPPORTS_VOTE');
  assert.equal(snap.data().aiEvidenceWeightMultiplier, 1.10);
  assert.equal(snap.data().aiAnalysisStatus, 'COMPLETE');

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
    { aiAnalysisFailureReason: 'TAMPERED' },
  ];
  for (const patch of forbiddenAdminPatches) {
    await assertFails(updateDoc(voteRef(admin, 'other', 'ai_admin_report'), patch));
  }

  // H: Legitimate Admin hazard management actions (Verify, Resolve, notifications) still succeed
  await assertSucceeds(decide(admin, 'Resolved', 'ai_admin_report'));
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

  // 1. Admin can write valid audit log entry
  await assertSucceeds(setDoc(auditLogRef(admin, 'audit_hazard', 'log1'), {
    action: 'REVIEWED_KEEP_VERIFIED',
    previousStatus: 'Verified',
    newStatus: 'Verified',
    performedBy: 'admin',
    performedByName: 'Admin Sherman',
    performedAt: serverTimestamp(),
    note: 'Reviewed community evidence and kept verified',
  }));

  // 2. Admin can read audit log
  const adminReadSnap = await assertSucceeds(getDoc(auditLogRef(admin, 'audit_hazard', 'log1')));
  assert.equal(adminReadSnap.data().action, 'REVIEWED_KEEP_VERIFIED');

  // 3. Tourist CANNOT read audit log
  await assertFails(getDoc(auditLogRef(tourist, 'audit_hazard', 'log1')));

  // 4. Tourist CANNOT create audit log
  await assertFails(setDoc(auditLogRef(tourist, 'audit_hazard', 'log2'), {
    action: 'REVIEWED_KEEP_VERIFIED',
    previousStatus: 'Verified',
    newStatus: 'Verified',
    performedBy: 'owner',
    performedAt: serverTimestamp(),
    note: 'Unauthorized tourist audit entry',
  }));

  // 5. Nobody can update or delete audit log
  await assertFails(updateDoc(auditLogRef(admin, 'audit_hazard', 'log1'), {
    note: 'Tampered note',
  }));

  // 6. Admin can perform Keep Verified update on hazard_report (Verified -> Verified)
  const batch = writeBatch(admin);
  batch.update(reportRef(admin, 'audit_hazard'), {
    reviewedBy: 'admin',
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batch.set(auditLogRef(admin, 'audit_hazard', 'log2'), {
    action: 'REVIEWED_KEEP_VERIFIED',
    previousStatus: 'Verified',
    newStatus: 'Verified',
    performedBy: 'admin',
    performedAt: serverTimestamp(),
    note: 'Atomic review action',
  });
  await assertSucceeds(batch.commit());
});
