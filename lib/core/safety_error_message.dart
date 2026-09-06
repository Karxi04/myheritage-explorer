import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import '../services/location_service.dart';

/// An unfinished evidence check is not a verdict about the photo's quality.
String friendlyEvidenceCheckError(Object error) {
  if (error is TimeoutException) {
    return 'The evidence check timed out. Check your connection and retry this photo.';
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'Your photo could not be checked. Sign in again or contact support.',
      'failed-precondition' =>
        'Photo checks are temporarily unavailable. Please try again later.',
      'unauthenticated' => 'Please sign in again, then retry the photo check.',
      'unavailable' || 'deadline-exceeded' =>
        'The evidence check could not connect. Check your connection and retry this photo.',
      'resource-exhausted' => 'Photo checks are busy. Please try again later.',
      _ => 'The photo check could not finish. Please retry.',
    };
  }
  return 'The photo check could not finish. Retry this photo. '
      'If it still fails, retake it or share this error with the app administrator.';
}

String friendlySafetyError(Object? error, {required String subject}) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'You do not currently have access to $subject. Sign in again or ask the project administrator to check your account access.';
  }
  if (error is FirebaseException && error.code == 'unavailable') {
    return '$subject could not be reached. Check your connection and try again.';
  }
  return 'We could not load $subject. Please try again in a moment.';
}

String friendlySafetyActionError(Object error, {required String fallback}) {
  if (error is LocationAccessException) return error.message;
  if (error is TimeoutException) {
    return 'This is taking longer than expected. Check your connection and location access, then retry.';
  }
  if (error is FirebaseException) {
    if (error.code == 'unauthenticated') {
      return 'Please sign in again to continue.';
    }
    if (error.code == 'permission-denied') {
      return 'This action is no longer available. Refresh the report or sign in again.';
    }
    return fallback;
  }
  return fallback;
}
