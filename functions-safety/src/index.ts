/**
 * Safety module Cloud Functions entry point.
 *
 * Initialises Firebase Admin SDK (once per cold start) and exports
 * all Safety module callable functions.
 */

import { initializeApp } from 'firebase-admin/app';

initializeApp();

export { analyzeHazardEvidence } from './safety/analyzeHazardEvidence';
export { recomputeSafetyConfidence } from './safety/recomputeHazardConfidence';
