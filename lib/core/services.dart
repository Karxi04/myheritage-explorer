import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';

import 'helpers.dart';
import 'notification_service.dart';

class AccountProfile {
  const AccountProfile({required this.role, required this.data});

  final String role;
  final Map<String, dynamic> data;
}

class VoucherClaimReceipt {
  const VoucherClaimReceipt({
    required this.claimId,
    required this.voucherTitle,
    required this.vendorName,
    required this.pointsSpent,
    required this.pointsRemaining,
    required this.claimedAt,
    this.expiresAt,
  });

  final String claimId;
  final String voucherTitle;
  final String vendorName;
  final int pointsSpent;
  final int pointsRemaining;
  final DateTime claimedAt;
  final DateTime? expiresAt;
}

class AppServices {
  static final auth = FirebaseAuth.instance;
  static final db = FirebaseFirestore.instance;
  static final storage = FirebaseStorage.instance;

  static DocumentReference<Map<String, dynamic>> adminRef(String uid) =>
      db.collection('admins').doc(uid);

  static DocumentReference<Map<String, dynamic>> travelerRef(String uid) =>
      db.collection('travelers').doc(uid);

  static DocumentReference<Map<String, dynamic>> vendorRef(String uid) =>
      db.collection('vendors').doc(uid);

  static DocumentReference<Map<String, dynamic>> profileRefForRole(
    String uid,
    String role,
  ) {
    return switch (role.toLowerCase()) {
      'admin' => adminRef(uid),
      'vendor' => vendorRef(uid),
      _ => travelerRef(uid),
    };
  }

  static String collectionNameForRole(String role) {
    return switch (role.toLowerCase()) {
      'admin' => 'admins',
      'vendor' => 'vendors',
      _ => 'travelers',
    };
  }

  static String labelForRole(String role) {
    return switch (role.toLowerCase()) {
      'admin' => 'administrator',
      'vendor' => 'vendor',
      _ => 'tourist',
    };
  }

  static Future<Map<String, dynamic>?> profileForRole(
    String uid,
    String role,
  ) async {
    return (await profileRefForRole(uid, role).get()).data();
  }

  static Future<bool> recoverRoleProfileFromEmail(String role) async {
    final user = auth.currentUser;
    final email = user?.email?.trim().toLowerCase();
    if (user == null || email == null || email.isEmpty) return false;

    final targetRef = profileRefForRole(user.uid, role);
    final current = await targetRef.get();
    if (_profileHasRole(current.data(), role)) return true;

    final matches = await db
        .collection(collectionNameForRole(role))
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (matches.docs.isEmpty) return false;

    final source = matches.docs.first;
    final data = source.data();
    if (!_profileHasRole(data, role)) return false;

    await targetRef.set({
      ...data,
      'uid': user.uid,
      'email': email,
      'role': role.toLowerCase(),
      'recoveredFromProfileId': source.id,
      'recoveredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return true;
  }

  static Future<AccountProfile?> currentAccountProfile() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return null;

    final admin = (await adminRef(uid).get()).data();
    if (_profileHasRole(admin, 'admin')) {
      return AccountProfile(role: 'admin', data: admin!);
    }

    final traveler = (await travelerRef(uid).get()).data();
    if (_profileHasRole(traveler, 'traveler')) {
      return AccountProfile(role: 'traveler', data: traveler!);
    }

    final vendor = (await vendorRef(uid).get()).data();
    if (_profileHasRole(vendor, 'vendor')) {
      return AccountProfile(role: 'vendor', data: vendor!);
    }

    return null;
  }

  static Future<Map<String, dynamic>?> currentProfile() async {
    return (await currentAccountProfile())?.data;
  }

  static bool _profileHasRole(Map<String, dynamic>? data, String role) {
    if (data == null) return false;
    return '${data['role'] ?? ''}'.trim().toLowerCase() == role;
  }

  static User _currentUserOrThrow() {
    final user = auth.currentUser;
    if (user == null) {
      throw Exception('No signed-in Firebase account was found.');
    }
    return user;
  }

  static Future<DocumentReference<Map<String, dynamic>>> accountRef(
    String uid,
  ) async {
    if ((await adminRef(uid).get()).exists) return adminRef(uid);
    if ((await travelerRef(uid).get()).exists) return travelerRef(uid);
    if ((await vendorRef(uid).get()).exists) return vendorRef(uid);

    throw Exception('The signed-in account profile was not found.');
  }

  static Stream<AccountProfile?> accountProfileStream(String uid) {
    late final StreamController<AccountProfile?> controller;

    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? adminSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? travelerSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? vendorSub;

    Map<String, dynamic>? adminData;
    Map<String, dynamic>? travelerData;
    Map<String, dynamic>? vendorData;

    var adminReady = false;
    var travelerReady = false;
    var vendorReady = false;

    void emit() {
      if (!adminReady || !travelerReady || !vendorReady) return;

      if (_profileHasRole(adminData, 'admin')) {
        controller.add(AccountProfile(role: 'admin', data: adminData!));
        return;
      }

      if (_profileHasRole(travelerData, 'traveler')) {
        controller.add(AccountProfile(role: 'traveler', data: travelerData!));
        return;
      }

      if (_profileHasRole(vendorData, 'vendor')) {
        controller.add(AccountProfile(role: 'vendor', data: vendorData!));
        return;
      }

      controller.add(null);
    }

    controller = StreamController<AccountProfile?>(
      onListen: () {
        adminSub = adminRef(uid).snapshots().listen((snapshot) {
          adminData = snapshot.data();
          adminReady = true;
          emit();
        }, onError: controller.addError);

        travelerSub = travelerRef(uid).snapshots().listen((snapshot) {
          travelerData = snapshot.data();
          travelerReady = true;
          emit();
        }, onError: controller.addError);

        vendorSub = vendorRef(uid).snapshots().listen((snapshot) {
          vendorData = snapshot.data();
          vendorReady = true;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await adminSub?.cancel();
        await travelerSub?.cancel();
        await vendorSub?.cancel();
      },
    );

    return controller.stream;
  }

  static Future<void> registerTraveler({
    required String email,
    required String password,
    required String fullName,
    required List<String> interests,
    required String budgetPreference,
    required String travelPace,
  }) async {
    final result = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    await result.user!.updateDisplayName(fullName.trim());
    await result.user!.sendEmailVerification();

    await createTravelerProfileForCurrentUser(
      fullName: fullName,
      interests: interests,
      budgetPreference: budgetPreference,
      travelPace: travelPace,
    );
  }

  static Future<void> createTravelerProfileForCurrentUser({
    required String fullName,
    required List<String> interests,
    required String budgetPreference,
    required String travelPace,
  }) async {
    final user = _currentUserOrThrow();
    await user.updateDisplayName(fullName.trim());

    await travelerRef(user.uid).set({
      'uid': user.uid,
      'email': user.email?.trim().toLowerCase(),
      'displayName': fullName.trim(),
      'role': 'traveler',
      'status': 'active',
      'emailVerified': user.emailVerified,
      'travelInterests': interests,
      'budgetPreference': budgetPreference,
      'travelPace': travelPace,
      'points': 0,
      'favoriteVoucherIds': <String>[],
      'notificationPreferences': {
        'nearbyRewards': true,
        'expiryReminders': true,
        'rewardUpdates': true,
        'backgroundLocationAlerts': false,
      },
      'localImpactScore': 0,
      'rank': 'Bronze',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> registerVendor({
    required String email,
    required String password,
    required String businessName,
    required String ownerName,
    required String category,
    required String contactNumber,
    required String shopLocation,
    required String businessHours,
    required String description,
    required double latitude,
    required double longitude,
    Uint8List? verificationBytes,
    String? verificationExtension,
    Uint8List? businessImageBytes,
    String? businessImageExtension,
  }) async {
    final result = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    await result.user!.updateDisplayName(businessName.trim());
    await result.user!.sendEmailVerification();

    await createVendorProfileForCurrentUser(
      businessName: businessName,
      ownerName: ownerName,
      category: category,
      contactNumber: contactNumber,
      shopLocation: shopLocation,
      businessHours: businessHours,
      description: description,
      latitude: latitude,
      longitude: longitude,
      verificationBytes: verificationBytes,
      verificationExtension: verificationExtension,
      businessImageBytes: businessImageBytes,
      businessImageExtension: businessImageExtension,
    );
  }

  static Future<void> createVendorProfileForCurrentUser({
    required String businessName,
    required String ownerName,
    required String category,
    required String contactNumber,
    required String shopLocation,
    required String businessHours,
    required String description,
    required double latitude,
    required double longitude,
    Uint8List? verificationBytes,
    String? verificationExtension,
    Uint8List? businessImageBytes,
    String? businessImageExtension,
  }) async {
    final user = _currentUserOrThrow();
    await user.updateDisplayName(businessName.trim());

    String? verificationUrl;
    if (verificationBytes != null) {
      final ref = storage.ref(
        'vendor_verification/${user.uid}/'
        'document.${verificationExtension ?? 'jpg'}',
      );
      await ref.putData(verificationBytes);
      verificationUrl = await ref.getDownloadURL();
    }

    String? businessImageUrl;
    if (businessImageBytes != null) {
      businessImageUrl = await uploadImage(
        folder: 'vendor_business_images',
        uid: user.uid,
        bytes: businessImageBytes,
        extension: businessImageExtension ?? 'jpg',
      );
    }

    final plannerCategories = _vendorPlannerCategories(category);
    final mapUrl = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$latitude,$longitude',
    }).toString();

    await vendorRef(user.uid).set({
      'uid': user.uid,
      'email': user.email?.trim().toLowerCase(),
      'displayName': businessName.trim(),
      'businessName': businessName.trim(),
      'ownerName': ownerName.trim(),
      'businessCategory': category,
      'plannerCategories': plannerCategories,
      'contactNumber': contactNumber.trim(),
      'shopLocation': shopLocation.trim(),
      'businessHours': businessHours.trim(),
      'businessDescription': description.trim(),
      'verificationDocumentUrl': verificationUrl,
      'imageUrl': businessImageUrl ?? '',
      'imageType': businessImageUrl == null
          ? 'map_preview'
          : 'vendor_uploaded_photo',
      'location': GeoPoint(latitude, longitude),
      'latitude': latitude,
      'longitude': longitude,
      'mapUrl': mapUrl,
      'state': 'Penang',
      'country': 'Malaysia',
      'budgetLevel': 'Medium',
      'role': 'vendor',
      'status': 'active',
      'vendorStatus': 'pending',
      'emailVerified': user.emailVerified,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static List<String> _vendorPlannerCategories(String category) {
    final value = category.toLowerCase();
    final categories = <String>{'Local Business'};

    if (value.contains('food') ||
        value.contains('cafe') ||
        value.contains('restaurant')) {
      categories.add('Food');
    }
    if (value.contains('heritage')) {
      categories.addAll(['Heritage', 'Culture']);
    }
    if (value.contains('craft') ||
        value.contains('workshop') ||
        value.contains('culture')) {
      categories.add('Culture');
    }
    if (value.contains('nature') || value.contains('eco')) {
      categories.add('Nature');
    }
    if (value.contains('art')) {
      categories.addAll(['Art', 'Culture']);
    }

    return categories.toList();
  }

  static Future<String> uploadImage({
    required String folder,
    required String uid,
    required Uint8List bytes,
    required String extension,
  }) async {
    final normalizedExtension = extension.toLowerCase();
    final contentType = switch (normalizedExtension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      _ => 'image/jpeg',
    };

    final ref = storage.ref(
      '$folder/$uid/'
      '${DateTime.now().millisecondsSinceEpoch}.$normalizedExtension',
    );

    await ref.putData(bytes, SettableMetadata(contentType: contentType));

    return ref.getDownloadURL();
  }

  static Future<void> reauthenticate(String password) async {
    final user = auth.currentUser;

    if (user == null || user.email == null) {
      throw Exception('No signed-in email account was found.');
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);
  }

  static Future<void> deactivateOwnAccount({
    bool deletionRequested = false,
  }) async {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception('No signed-in user was found.');
    }

    final profileRef = await accountRef(user.uid);
    await profileRef.update({
      'status': 'inactive',
      'deletionRequested': deletionRequested,
      if (deletionRequested)
        'deletionRequestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await auth.signOut();
  }

  static bool notificationPreference(
    Map<String, dynamic>? profile,
    String key, {
    required bool defaultValue,
  }) {
    final raw = profile?['notificationPreferences'];
    if (raw is Map && raw[key] is bool) return raw[key] as bool;
    return defaultValue;
  }

  static Future<void> setNotificationPreference(
    String key,
    bool enabled,
  ) async {
    final user = _currentUserOrThrow();
    await travelerRef(user.uid).update({
      'notificationPreferences.$key': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<LocationPermission> requestBackgroundLocationAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Turn on device location services first.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  static Future<bool> _notificationAllowed(String userId, String type) async {
    final key = switch (type) {
      'voucher_nearby' => 'nearbyRewards',
      'voucher_expiry' => 'expiryReminders',
      'voucher_claimed' || 'voucher_redeemed' => 'rewardUpdates',
      _ => null,
    };
    if (key == null) return true;
    try {
      final profile = (await travelerRef(userId).get()).data();
      return notificationPreference(profile, key, defaultValue: true);
    } catch (_) {
      return true;
    }
  }

  static Future<void> notify({
    required String userId,
    required String title,
    required String message,
    String type = 'general',
    String? referenceId,
  }) async {
    if (!await _notificationAllowed(userId, type)) return;
    try {
      await db.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'referenceId': referenceId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    // A client device must never display a local notification intended for a
    // different account (for example, while an administrator approves a
    // tourist's task). The Firestore notification is still written above.
    if (auth.currentUser?.uid == userId) {
      try {
        final notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
        final payload = switch (type) {
          'itinerary' when referenceId != null => 'itinerary:$referenceId',
          'voucher_nearby' when referenceId != null => 'reward:$referenceId',
          'voucher_claimed' || 'voucher_redeemed' => 'voucher_wallet',
          _ => null,
        };
        await SystemNotificationService.instance.showInstantNotification(
          id: notifId,
          title: title,
          body: message,
          payload: payload,
        );
      } catch (_) {}
    }
  }

  static Future<void> scheduleTripNotification({
    required String userId,
    required String itineraryId,
    required String title,
    required String area,
    required DateTime tripStartDate,
    DateTime? tripEndDate,
  }) async {
    final formattedDate =
        '${tripStartDate.day}/${tripStartDate.month}/${tripStartDate.year}';
    final inAppTitle = '📅 Trip Scheduled: $title';
    final inAppMessage =
        'Your itinerary for $area is scheduled for $formattedDate. We will send you a reminder before departure!';

    await notify(
      userId: userId,
      title: inAppTitle,
      message: inAppMessage,
      type: 'itinerary',
      referenceId: itineraryId,
    );

    // Schedule 1 day before at 9:00 AM (or on start date at 8:00 AM if trip is tomorrow/today)
    final now = DateTime.now();
    DateTime reminderDate = DateTime(
      tripStartDate.year,
      tripStartDate.month,
      tripStartDate.day,
      8,
      0,
    ).subtract(const Duration(days: 1));

    if (reminderDate.isBefore(now)) {
      reminderDate = DateTime(
        tripStartDate.year,
        tripStartDate.month,
        tripStartDate.day,
        8,
        0,
      );
    }

    final notifId = itineraryId.hashCode.abs().remainder(100000);
    await SystemNotificationService.instance.scheduleTripReminder(
      id: notifId,
      title: '✈️ Upcoming Trip: $title ($area)',
      body:
          'Your trip to $area starts tomorrow ($formattedDate)! Check your itinerary & today\'s weather forecast.',
      reminderTime: reminderDate,
      payload: 'itinerary:$itineraryId',
    );
  }

  static String getItineraryStatus(Map<String, dynamic> itinerary) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime? startDate;
    DateTime? endDate;

    if (itinerary['startDate'] != null) {
      startDate = asDate(itinerary['startDate']);
    } else if (itinerary['targetDate'] != null) {
      startDate = asDate(itinerary['targetDate']);
    }

    if (itinerary['endDate'] != null) {
      endDate = asDate(itinerary['endDate']);
    }

    if (startDate == null) {
      final createdAt = asDate(itinerary['createdAt']);
      if (createdAt != null && now.difference(createdAt).inDays > 14) {
        return 'expired';
      }
      return 'ongoing';
    }

    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = endDate != null
        ? DateTime(endDate.year, endDate.month, endDate.day)
        : startDay;

    if (today.isBefore(startDay)) {
      return 'upcoming';
    } else if (today.isAfter(endDay)) {
      return 'expired';
    } else {
      return 'ongoing';
    }
  }

  static Future<VoucherClaimReceipt> claimVoucher({
    required String voucherId,
    required Map<String, dynamic> voucher,
  }) async {
    final signedInUser = auth.currentUser;
    if (signedInUser == null) {
      throw Exception('Please sign in as a traveler first.');
    }

    final uid = signedInUser.uid;
    final travelerProfileRef = travelerRef(uid);
    final voucherRef = db.collection('vouchers').doc(voucherId);
    final legacyClaimRef = db
        .collection('claimed_vouchers')
        .doc('${uid}_$voucherId');
    final counterRef = db
        .collection('voucher_claim_counts')
        .doc('${uid}_$voucherId');
    final claimRef = db
        .collection('claimed_vouchers')
        .doc('${uid}_${voucherId}_${randomToken(10)}');

    var claimedTitle = 'Voucher';
    var vendorName = 'Registered vendor';
    var pointsSpent = 0;
    var pointsRemaining = 0;
    DateTime? claimExpiry;

    await db.runTransaction((transaction) async {
      final travelerSnapshot = await transaction.get(travelerProfileRef);
      final voucherSnapshot = await transaction.get(voucherRef);
      final counterSnapshot = await transaction.get(counterRef);
      final legacyClaimSnapshot = await transaction.get(legacyClaimRef);

      if (!travelerSnapshot.exists) {
        throw Exception('Traveler profile was not found.');
      }
      if (!voucherSnapshot.exists) {
        throw Exception('This voucher is no longer available.');
      }

      final traveler = travelerSnapshot.data()!;
      final currentVoucher = voucherSnapshot.data()!;
      final vendorId = '${currentVoucher['vendorId'] ?? ''}'.trim();
      if (vendorId.isEmpty) {
        throw Exception('This voucher is not linked to a registered vendor.');
      }
      final vendorSnapshot = await transaction.get(vendorRef(vendorId));

      if (traveler['role'] != 'traveler') {
        throw Exception('Only travelers can claim vouchers.');
      }
      if (traveler['status'] != 'active') {
        throw Exception('This traveler account is not active.');
      }
      if (!vendorSnapshot.exists) {
        throw Exception('The vendor linked to this voucher was not found.');
      }

      final vendor = vendorSnapshot.data()!;
      if (vendor['status'] != 'active' ||
          vendor['vendorStatus'] != 'verified') {
        throw Exception('The vendor linked to this voucher is unavailable.');
      }

      final cost = (currentVoucher['pointCost'] as num?)?.toInt() ?? 0;
      final currentPoints = (traveler['points'] as num?)?.toInt() ?? 0;
      final inventory =
          (currentVoucher['inventoryRemaining'] as num?)?.toInt() ?? 0;
      final claimLimit =
          ((currentVoucher['perTouristClaimLimit'] as num?)?.toInt() ?? 1)
              .clamp(1, 10);
      final recordedCount =
          (counterSnapshot.data()?['count'] as num?)?.toInt() ?? 0;
      final currentClaimCount = max(
        recordedCount,
        legacyClaimSnapshot.exists ? 1 : 0,
      );

      if (cost <= 0) {
        throw Exception(
          'This voucher has an invalid point cost and cannot be claimed.',
        );
      }
      if (currentPoints < cost) {
        throw Exception(
          'Insufficient points. You need ${cost - currentPoints} more points.',
        );
      }
      if (currentVoucher['status'] != 'active') {
        throw Exception('This voucher is not active.');
      }

      final now = DateTime.now();
      final startsAt = asDate(currentVoucher['startsAt']);
      if (startsAt != null && startsAt.isAfter(now)) {
        throw Exception(
          'This voucher becomes available on ${startsAt.day}/${startsAt.month}/${startsAt.year}.',
        );
      }
      final expiry = asDate(currentVoucher['expiresAt']);
      if (expiry != null && !expiry.isAfter(now)) {
        throw Exception('This voucher has expired.');
      }
      if (inventory <= 0) {
        throw Exception('This reward is fully claimed.');
      }
      if (currentClaimCount >= claimLimit) {
        throw Exception(
          claimLimit == 1
              ? 'You already claimed this voucher.'
              : 'You have reached the limit of $claimLimit claims for this voucher.',
        );
      }

      final pointsAfterClaim = currentPoints - cost;
      claimedTitle = '${currentVoucher['title'] ?? 'Voucher'}'.trim();
      vendorName =
          '${currentVoucher['vendorName'] ?? vendor['businessName'] ?? vendor['displayName'] ?? 'Registered vendor'}';
      pointsSpent = cost;
      pointsRemaining = pointsAfterClaim;
      claimExpiry = expiry;
      final rawInterests = traveler['travelInterests'];
      final interestTags = rawInterests is Iterable
          ? rawInterests
                .map((value) => '$value'.trim())
                .where((value) => value.isNotEmpty)
                .take(6)
                .toList()
          : <String>[];

      transaction.update(travelerProfileRef, {
        'points': pointsAfterClaim,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(voucherRef, {
        'inventoryRemaining': inventory - 1,
        'claimCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(counterRef, {
        'userId': uid,
        'voucherId': voucherId,
        'count': currentClaimCount + 1,
        'limit': claimLimit,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(claimRef, {
        'travelerId': uid,
        'userId': uid,
        'voucherId': voucherId,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'vendorCategory': currentVoucher['vendorCategory'],
        'vendorAddress':
            currentVoucher['vendorAddress'] ?? vendor['shopLocation'],
        if (currentVoucher['location'] != null)
          'location': currentVoucher['location'],
        'title': claimedTitle,
        'description': currentVoucher['description'],
        'terms': currentVoucher['terms'],
        'pointCost': cost,
        'pointsBeforeClaim': currentPoints,
        'pointsAfterClaim': pointsAfterClaim,
        'interestTags': interestTags,
        'token': randomToken(),
        'redemptionPin': randomNumericCode(),
        'claimSequence': currentClaimCount + 1,
        'claimLimit': claimLimit,
        'status': 'claimed',
        'claimedAt': FieldValue.serverTimestamp(),
        'expiresAt': currentVoucher['expiresAt'],
      });
    });

    await notify(
      userId: uid,
      title: 'Voucher added to wallet',
      message: '$claimedTitle is ready to use. Show its QR code at the vendor.',
      type: 'voucher_claimed',
      referenceId: claimRef.id,
    );
    await syncVoucherExpiryReminders();

    return VoucherClaimReceipt(
      claimId: claimRef.id,
      voucherTitle: claimedTitle,
      vendorName: vendorName,
      pointsSpent: pointsSpent,
      pointsRemaining: pointsRemaining,
      claimedAt: DateTime.now(),
      expiresAt: claimExpiry,
    );
  }

  static Future<
    ({
      DocumentReference<Map<String, dynamic>> claimRef,
      String? qrToken,
      String? pin,
    })
  >
  _resolveRedemptionCode(String rawCode, String vendorId) async {
    final code = rawCode.trim();
    final parts = code.split('|');
    if (parts.length == 2 && parts.every((part) => part.isNotEmpty)) {
      return (
        claimRef: db.collection('claimed_vouchers').doc(parts[0]),
        qrToken: parts[1],
        pin: null,
      );
    }

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw Exception('Enter a valid QR code or 6-digit redemption PIN.');
    }
    final matches = await db
        .collection('claimed_vouchers')
        .where('vendorId', isEqualTo: vendorId)
        .get();
    final matchingClaims = matches.docs.where((doc) {
      final data = doc.data();
      return '${data['redemptionPin'] ?? ''}' == code &&
          data['status'] == 'claimed';
    }).toList();
    if (matchingClaims.isEmpty) {
      throw Exception('Invalid or expired redemption PIN.');
    }
    if (matchingClaims.length > 1) {
      throw Exception(
        'This PIN is ambiguous. Please scan the QR code instead.',
      );
    }
    return (
      claimRef: matchingClaims.single.reference,
      qrToken: null,
      pin: code,
    );
  }

  static Future<String> redeemClaim(String rawCode, String vendorId) async {
    final signedInUser = auth.currentUser;
    if (signedInUser == null || signedInUser.uid != vendorId) {
      throw Exception(
        'Please sign in with the vendor account that owns this voucher.',
      );
    }

    final resolved = await _resolveRedemptionCode(rawCode, vendorId);
    final claimRef = resolved.claimRef;
    final redemptionRef = db.collection('redemptions').doc();
    String travelerId = '';
    var voucherTitle = 'Voucher';

    await db.runTransaction((transaction) async {
      final claimSnapshot = await transaction.get(claimRef);
      final vendorSnapshot = await transaction.get(vendorRef(vendorId));
      if (!claimSnapshot.exists) {
        throw Exception('Voucher claim was not found.');
      }
      if (!vendorSnapshot.exists ||
          vendorSnapshot.data()?['role'] != 'vendor' ||
          vendorSnapshot.data()?['status'] != 'active' ||
          vendorSnapshot.data()?['vendorStatus'] != 'verified') {
        throw Exception('This vendor account is not active and verified.');
      }

      final claim = claimSnapshot.data()!;
      if (resolved.qrToken != null && claim['token'] != resolved.qrToken) {
        throw Exception('Invalid voucher token.');
      }
      if (resolved.pin != null && claim['redemptionPin'] != resolved.pin) {
        throw Exception('Invalid redemption PIN.');
      }
      if (claim['vendorId'] != vendorId) {
        throw Exception('This voucher belongs to another vendor.');
      }
      if (claim['status'] != 'claimed') {
        throw Exception('Voucher is already redeemed or unavailable.');
      }

      final expiry = asDate(claim['expiresAt']);
      if (expiry != null && !expiry.isAfter(DateTime.now())) {
        throw Exception('Voucher has expired.');
      }

      travelerId = '${claim['travelerId'] ?? claim['userId'] ?? ''}';
      if (travelerId.isEmpty) {
        throw Exception('The voucher owner could not be identified.');
      }
      voucherTitle = '${claim['title'] ?? 'Voucher'}'.trim();

      transaction.update(claimRef, {
        'status': 'redeemed',
        'redeemedAt': FieldValue.serverTimestamp(),
        'redemptionMethod': resolved.pin == null ? 'qr' : 'pin',
      });
      transaction.set(redemptionRef, {
        'claimId': claimRef.id,
        'voucherId': claim['voucherId'],
        'voucherTitle': voucherTitle,
        'vendorId': vendorId,
        'vendorName': claim['vendorName'],
        'travelerId': travelerId,
        'pointCost': claim['pointCost'],
        'interestTags': claim['interestTags'] ?? const <String>[],
        'redemptionMethod': resolved.pin == null ? 'qr' : 'pin',
        'redeemedAt': FieldValue.serverTimestamp(),
      });
    });

    await notify(
      userId: travelerId,
      title: 'Redemption successful',
      message: '$voucherTitle was successfully redeemed.',
      type: 'voucher_redeemed',
      referenceId: claimRef.id,
    );

    return claimRef.id;
  }

  static Future<Map<String, dynamic>> redemptionPreview(
    String rawCode,
    String vendorId,
  ) async {
    final signedInUser = auth.currentUser;
    if (signedInUser == null || signedInUser.uid != vendorId) {
      throw Exception(
        'Please sign in with the vendor account that owns this voucher.',
      );
    }

    final resolved = await _resolveRedemptionCode(rawCode, vendorId);
    final claimSnapshot = await resolved.claimRef.get();
    final vendorSnapshot = await vendorRef(vendorId).get();
    if (!claimSnapshot.exists) {
      throw Exception('Voucher claim was not found.');
    }
    if (!vendorSnapshot.exists ||
        vendorSnapshot.data()?['role'] != 'vendor' ||
        vendorSnapshot.data()?['status'] != 'active' ||
        vendorSnapshot.data()?['vendorStatus'] != 'verified') {
      throw Exception('This vendor account is not active and verified.');
    }

    final claim = claimSnapshot.data()!;
    if (resolved.qrToken != null && claim['token'] != resolved.qrToken) {
      throw Exception('Invalid voucher token.');
    }
    if (resolved.pin != null && claim['redemptionPin'] != resolved.pin) {
      throw Exception('Invalid redemption PIN.');
    }
    if (claim['vendorId'] != vendorId) {
      throw Exception('This voucher belongs to another vendor.');
    }
    if (claim['status'] != 'claimed') {
      throw Exception('Voucher is already redeemed or unavailable.');
    }

    final expiry = asDate(claim['expiresAt']);
    if (expiry != null && !expiry.isAfter(DateTime.now())) {
      throw Exception('Voucher has expired.');
    }

    return <String, dynamic>{...claim, 'claimId': claimSnapshot.id};
  }

  static Future<void> syncVoucherExpiryReminders() async {
    final user = auth.currentUser;
    if (user == null) return;
    final profile = (await travelerRef(user.uid).get()).data();
    final enabled = notificationPreference(
      profile,
      'expiryReminders',
      defaultValue: true,
    );
    final claims = await db
        .collection('claimed_vouchers')
        .where('userId', isEqualTo: user.uid)
        .get();

    for (final doc in claims.docs) {
      final threeDayId = stableNotificationId(doc.id, 3);
      final oneDayId = stableNotificationId(doc.id, 1);
      await SystemNotificationService.instance.cancelNotification(threeDayId);
      await SystemNotificationService.instance.cancelNotification(oneDayId);

      final claim = doc.data();
      final expiry = asDate(claim['expiresAt']);
      if (!enabled || claim['status'] != 'claimed' || expiry == null) continue;

      final reminderBase = DateTime(expiry.year, expiry.month, expiry.day, 9);
      final title = '${claim['title'] ?? 'Voucher'}';
      for (final days in const [3, 1]) {
        final reminderTime = reminderBase.subtract(Duration(days: days));
        if (!reminderTime.isAfter(DateTime.now())) continue;
        await SystemNotificationService.instance.scheduleRewardExpiryReminder(
          id: days == 3 ? threeDayId : oneDayId,
          voucherTitle: title,
          reminderTime: reminderTime,
          daysRemaining: days,
        );
      }
    }
  }

  static Future<int> archiveExpiredVouchers(String vendorId) async {
    final snapshot = await db
        .collection('vouchers')
        .where('vendorId', isEqualTo: vendorId)
        .get();
    final now = DateTime.now();
    final expired = snapshot.docs.where((doc) {
      final data = doc.data();
      final expiry = asDate(data['expiresAt']);
      return data['status'] == 'active' &&
          expiry != null &&
          !expiry.isAfter(now);
    }).toList();

    if (expired.isEmpty) return 0;
    final batch = db.batch();
    for (final doc in expired) {
      batch.update(doc.reference, {
        'status': 'expired',
        'archivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return expired.length;
  }

  static Future<int> checkNearbyRewardNotifications({
    Position? currentPosition,
    bool requestPermission = false,
  }) async {
    final user = auth.currentUser;
    if (user == null) return 0;

    final traveler = (await travelerRef(user.uid).get()).data();
    if (traveler == null ||
        traveler['role'] != 'traveler' ||
        traveler['status'] != 'active') {
      return 0;
    }
    if (!notificationPreference(
      traveler,
      'nearbyRewards',
      defaultValue: true,
    )) {
      return 0;
    }

    Position position;
    if (currentPosition != null) {
      position = currentPosition;
    } else {
      if (!await Geolocator.isLocationServiceEnabled()) return 0;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && !requestPermission) {
        return 0;
      }
      if (permission == LocationPermission.deniedForever) return 0;
      position = await determinePosition();
    }

    final snapshot = await db
        .collection('vouchers')
        .where('status', isEqualTo: 'active')
        .get();
    final now = DateTime.now();
    final matches =
        <
          ({QueryDocumentSnapshot<Map<String, dynamic>> doc, double distance})
        >[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final location = data['location'];
      final startsAt = asDate(data['startsAt']);
      final expiry = asDate(data['expiresAt']);
      final remaining = (data['inventoryRemaining'] as num?)?.toInt() ?? 0;
      if (location is! GeoPoint ||
          remaining <= 0 ||
          (startsAt != null && startsAt.isAfter(now)) ||
          (expiry != null && !expiry.isAfter(now))) {
        continue;
      }

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        location.latitude,
        location.longitude,
      );
      final radius = ((data['notificationRadiusMeters'] ?? 750) as num)
          .toDouble();
      if (distance <= radius) matches.add((doc: doc, distance: distance));
    }

    matches.sort((a, b) => a.distance.compareTo(b.distance));
    var alertCount = 0;
    for (final match in matches.take(3)) {
      final voucher = match.doc.data();
      final alertRef = db
          .collection('reward_proximity_alerts')
          .doc('${user.uid}_${match.doc.id}');
      var shouldNotify = false;

      await db.runTransaction((transaction) async {
        shouldNotify = false;
        final previous = await transaction.get(alertRef);
        final lastNotifiedAt = asDate(previous.data()?['lastNotifiedAt']);
        if (lastNotifiedAt != null &&
            now.difference(lastNotifiedAt) < const Duration(hours: 24)) {
          return;
        }
        transaction.set(alertRef, {
          'userId': user.uid,
          'voucherId': match.doc.id,
          'vendorId': voucher['vendorId'],
          'lastDistanceMeters': match.distance.round(),
          'lastNotifiedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        shouldNotify = true;
      });

      if (!shouldNotify) continue;
      final distanceLabel = match.distance < 1000
          ? '${match.distance.round()} m away'
          : '${(match.distance / 1000).toStringAsFixed(1)} km away';
      await notify(
        userId: user.uid,
        title: 'Nearby reward available',
        message:
            '${voucher['title'] ?? 'A local voucher'} at ${voucher['vendorName'] ?? 'a verified vendor'} is $distanceLabel.',
        type: 'voucher_nearby',
        referenceId: match.doc.id,
      );
      alertCount += 1;
    }
    return alertCount;
  }

  static Future<void> seedInitialReviewsIfEmpty() async {
    try {
      final vendorsSnapshot = await db.collection('vendors').limit(1).get();
      if (vendorsSnapshot.docs.isEmpty) {
        await syncCuratedVendorsToFirestore();
      } else {
        final reviewsSnapshot = await db.collection('reviews').limit(1).get();
        if (reviewsSnapshot.docs.isEmpty) {
          await seedVendorReviews(force: true);
        }
      }
    } catch (_) {
      // Non-blocking initialization
    }
  }

  static Future<int> syncCuratedVendorsToFirestore() async {
    final curatedPlaces = [
      {
        'name': 'Sentosa Food Court BM',
        'category': 'Food',
        'area': 'Bukit Mertajam',
        'formattedAddress':
            'Jalan Sentosa, Taman Sentosa, 14000 Bukit Mertajam, Penang, Malaysia',
        'score': 4.7,
        'phone': '+604-539 8888',
        'openingHours': 'Mon-Sun 17:00-00:00',
        'durationMinutes': 60,
        'budgetLevel': 'Low',
        'location': {'latitude': 5.3488, 'longitude': 100.4722},
        'description':
            'Bustling evening food court in Taman Sentosa featuring over 40 hawker stalls serving BBQ stingray, satay, fried oyster omelette, and claypot noodles.',
        'culturalTask': {
          'title': 'Sentosa Evening Hawker Food Feast',
          'description':
              'Sample authentic local street food and photograph your dinner spread at Sentosa Food Court.',
          'rewardPoints': 80,
        },
      },
      {
        'name': 'Restoran BM Yam Rice',
        'category': 'Food',
        'area': 'Bukit Mertajam',
        'formattedAddress':
            '7 Jalan Murthy, 14000 Bukit Mertajam, Penang, Malaysia',
        'score': 4.8,
        'phone': '+604-530 6826',
        'openingHours': 'Mon-Sun 09:00-15:00',
        'durationMinutes': 45,
        'budgetLevel': 'Low',
        'location': {'latitude': 5.3644, 'longitude': 100.4611},
        'description':
            'Legendary Bukit Mertajam yam rice served with hot salted mustard green pork soup, tender offal, and spicy chili dip.',
        'culturalTask': {
          'title': 'Legendary Yam Rice Tasting',
          'description':
              'Taste authentic BM Yam Rice with salted vegetable soup and take a photo of the signature dish.',
          'rewardPoints': 90,
        },
      },
      {
        'name': 'Restoran BM Cup Rice (Danby Cup Rice)',
        'category': 'Food',
        'area': 'Bukit Mertajam',
        'formattedAddress':
            'Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia',
        'score': 4.7,
        'phone': '+6012-421 8833',
        'openingHours': 'Mon-Sun 08:00-14:00',
        'durationMinutes': 40,
        'budgetLevel': 'Low',
        'location': {'latitude': 5.3639, 'longitude': 100.4608},
        'description':
            'Iconic vintage BM cup rice drenched in rich roasted pork gravy with tender char siew.',
        'culturalTask': {
          'title': 'Heritage Cup Rice Experience',
          'description':
              'Enjoy the classic BM cup rice and capture the vintage street ambience.',
          'rewardPoints': 85,
        },
      },
      {
        'name': 'BM Famous Duck Egg Char Koay Teow',
        'category': 'Food',
        'area': 'Bukit Mertajam',
        'formattedAddress':
            'Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia',
        'score': 4.9,
        'phone': '+6016-443 2819',
        'openingHours': 'Mon-Sun 19:00-23:30',
        'durationMinutes': 45,
        'budgetLevel': 'Low',
        'location': {'latitude': 5.3635, 'longitude': 100.4602},
        'description':
            'Famous charcoal-fried char koay teow cooked with rich creamy duck egg, fresh cockles, and fragrant wok hei.',
        'culturalTask': {
          'title': 'Duck Egg Wok Hei Snap',
          'description':
              'Order the signature duck egg Char Koay Teow and photograph the master stir-frying with charcoal wok hei.',
          'rewardPoints': 95,
        },
      },
      {
        'name': 'BM Rojak Orang Hitam Putih',
        'category': 'Food',
        'area': 'Bukit Mertajam',
        'formattedAddress':
            'Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia',
        'score': 4.8,
        'phone': '+6012-475 2288',
        'openingHours': 'Mon-Sun 11:30-18:30',
        'durationMinutes': 30,
        'budgetLevel': 'Low',
        'location': {'latitude': 5.3641, 'longitude': 100.4615},
        'description':
            'Renowned BM fruit and fritter rojak tossed in thick, aromatic black shrimp paste and crushed peanuts.',
      },
      {
        'name': 'Minor Basilica of St. Anne',
        'category': 'Heritage',
        'area': 'Bukit Mertajam',
        'formattedAddress':
            'Jalan Kulim, 14000 Bukit Mertajam, Penang, Malaysia',
        'score': 4.9,
        'phone': '+604-538 6405',
        'website': 'https://stannebm.org/',
        'openingHours': 'Mon-Sun 06:30-21:00',
        'durationMinutes': 60,
        'budgetLevel': 'Free',
        'location': {'latitude': 5.3533, 'longitude': 100.4789},
        'description':
            'Historic Catholic pilgrimage site elevated to Minor Basilica status, featuring Gothic architecture and the 1888 Old Shrine.',
        'culturalTask': {
          'title': 'Basilica Architecture Discovery',
          'description':
              'Photograph the gothic facade of St. Anne Basilica and the historic 1888 hillside chapel.',
          'rewardPoints': 110,
        },
      },
      {
        'name': 'Pinang Peranakan Mansion',
        'category': 'Heritage',
        'area': 'George Town',
        'formattedAddress':
            '29 Church Street, 10200 George Town, Penang, Malaysia',
        'score': 4.8,
        'phone': '+604-264 2929',
        'website': 'https://www.pinangperanakanmansion.com.my/',
        'openingHours': 'Mon-Sun 09:30-17:30',
        'durationMinutes': 75,
        'budgetLevel': 'Medium',
        'location': {'latitude': 5.41758, 'longitude': 100.34262},
        'description':
            'A stately recreation of a rich 19th-century Baba Nyonya residence showcasing over 1,000 antique Peranakan heirlooms.',
        'culturalTask': {
          'title': 'Peranakan Heritage Discovery',
          'description':
              'Photograph one traditional Baba Nyonya antique or architectural carving.',
          'rewardPoints': 120,
        },
      },
      {
        'name': 'Cheong Fatt Tze - The Blue Mansion',
        'category': 'Heritage',
        'area': 'George Town',
        'formattedAddress':
            '14 Leith Street, 10200 George Town, Penang, Malaysia',
        'score': 4.7,
        'phone': '+604-262 0006',
        'website': 'https://www.cheongfatttzemansion.com/',
        'openingHours': 'Mon-Sun 11:00-18:00',
        'durationMinutes': 75,
        'budgetLevel': 'High',
        'location': {'latitude': 5.42157, 'longitude': 100.33407},
        'description':
            'Award-winning UNESCO-conserved 1890s courtyard mansion famous for its striking indigo blue walls.',
        'culturalTask': {
          'title': 'Indigo Architectural Snapshot',
          'description':
              'Photograph the iconic indigo courtyard and identify one unique Feng Shui element.',
          'rewardPoints': 130,
        },
      },
      {
        'name': 'Pasar Besar Siti Khadijah',
        'category': 'Heritage',
        'area': 'Kota Bharu',
        'formattedAddress':
            'Jalan Buluh Kubu, Bandar Kota Bharu, 15000 Kota Bharu, Kelantan, Malaysia',
        'score': 4.8,
        'phone': '+609-748 2140',
        'openingHours': 'Mon-Sun 07:00-18:00',
        'durationMinutes': 75,
        'budgetLevel': 'Low',
        'location': {'latitude': 6.1287, 'longitude': 102.2392},
        'description':
            'Iconic 4-storey octagonal central market in Kota Bharu operated mostly by female traders.',
        'culturalTask': {
          'title': 'Octagonal Market Geometry & Kuih Akok',
          'description':
              'Photograph the colourful central octagonal produce hall and sample warm Kuih Akok.',
          'rewardPoints': 130,
        },
      },
      {
        'name': 'Masjid Kristal',
        'category': 'Heritage',
        'area': 'Kuala Terengganu',
        'formattedAddress':
            'Pulau Wan Man, 21000 Kuala Terengganu, Terengganu, Malaysia',
        'score': 4.8,
        'phone': '+609-627 8888',
        'openingHours': 'Mon-Sun 06:00-22:00',
        'durationMinutes': 60,
        'budgetLevel': 'Free',
        'location': {'latitude': 5.3224, 'longitude': 103.1189},
        'description':
            'Magnificent grand mosque built from steel, glass, and crystal on Pulau Wan Man.',
        'culturalTask': {
          'title': 'Crystal Reflection Snapshot',
          'description':
              'Photograph the gleaming crystal and glass domes reflecting over the Terengganu River.',
          'rewardPoints': 120,
        },
      },
      {
        'name': 'Borneo Cultures Museum',
        'category': 'Culture',
        'area': 'Kuching',
        'formattedAddress':
            'Jalan Tun Abang Haji Openg, 93000 Kuching, Sarawak, Malaysia',
        'score': 4.9,
        'phone': '+6082-536 788',
        'website': 'https://museum.sarawak.gov.my/',
        'openingHours': 'Mon-Fri 09:00-16:45, Sat-Sun 09:30-16:30',
        'durationMinutes': 120,
        'budgetLevel': 'Medium',
        'location': {'latitude': 1.5546, 'longitude': 110.3421},
        'description':
            'Iconic 5-storey museum and the second largest in Southeast Asia, housing over 1,000 Borneo cultural artefacts.',
        'culturalTask': {
          'title': 'Indigenous Tribal Arts Study',
          'description':
              'Explore Level 3 or 4 and photograph one traditional Dayak craft or textile heirloom.',
          'rewardPoints': 150,
        },
      },
      {
        'name': 'Batu Caves Lord Murugan Shrine',
        'category': 'Heritage',
        'area': 'Selangor',
        'formattedAddress': 'Gombak, 68100 Batu Caves, Selangor, Malaysia',
        'score': 4.8,
        'phone': '+603-6189 6284',
        'openingHours': 'Mon-Sun 06:00-21:00',
        'durationMinutes': 90,
        'budgetLevel': 'Free',
        'location': {'latitude': 3.2379, 'longitude': 101.6840},
        'description':
            'Limestone hill comprising three major caves, world-renowned 140-ft golden Lord Murugan statue, and 272 colourful rainbow steps.',
        'culturalTask': {
          'title': 'Cathedral Cave Step Ascent',
          'description':
              'Climb the 272 rainbow steps and photograph the limestone cathedral cave interior.',
          'rewardPoints': 130,
        },
      },
    ];

    int count = 0;
    for (final place in curatedPlaces) {
      final name = '${place['name'] ?? ''}'.trim();
      final slug = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .trim();
      final vendorId = 'vendor_$slug';
      final placeId = 'place_$slug';

      final category = '${place['category'] ?? 'Heritage'}';
      final area = '${place['area'] ?? 'Malaysia'}';
      final address = '${place['formattedAddress'] ?? area}';
      final score = (place['score'] as num?)?.toDouble() ?? 4.8;
      final phone = '${place['phone'] ?? '+604-500 0000'}';
      final website = '${place['website'] ?? ''}';
      final openingHours = '${place['openingHours'] ?? 'Mon-Sun 09:00-18:00'}';
      final duration = (place['durationMinutes'] as num?)?.toInt() ?? 60;
      final budget = '${place['budgetLevel'] ?? 'Low'}';
      final desc = '${place['description'] ?? ''}';
      final loc = place['location'];

      final emailSlug = slug.replaceAll('_', '');
      final vendorEmail = '$emailSlug@myheritage.my';

      await db.collection('vendors').doc(vendorId).set({
        'uid': vendorId,
        'vendorId': vendorId,
        'businessName': name,
        'displayName': name,
        'ownerName': '$name Management',
        'email': vendorEmail,
        'phone': phone,
        'category': category,
        'area': area,
        'formattedAddress': address,
        'location': loc,
        'role': 'vendor',
        'status': 'active',
        'vendorStatus': 'verified',
        'score': score,
        'website': website,
        'openingHours': openingHours,
        'description': desc,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await db.collection('places').doc(placeId).set({
        'placeId': placeId,
        'vendorId': vendorId,
        'name': name,
        'category': category,
        'area': area,
        'formattedAddress': address,
        'location': loc,
        'score': score,
        'durationMinutes': duration,
        'budgetLevel': budget,
        'phone': phone,
        'website': website,
        'openingHours': openingHours,
        'description': desc,
        'culturalTask': place['culturalTask'],
        'status': 'active',
        'trustLabel': 'High Trust',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      count++;
    }

    await seedVendorReviews(force: true);
    return count;
  }

  static Future<int> seedVendorReviews({bool force = false}) async {
    final reviewsCollection = db.collection('reviews');
    final existingReviewsSnapshot = await reviewsCollection.get();

    final existingPlaceIds = existingReviewsSnapshot.docs
        .map(
          (doc) =>
              '${doc.data()['placeId'] ?? doc.data()['vendorId'] ?? ''}'.trim(),
        )
        .where((id) => id.isNotEmpty)
        .toSet();

    final targets = <Map<String, dynamic>>[];

    try {
      final vendorsSnapshot = await db.collection('vendors').get();
      for (final doc in vendorsSnapshot.docs) {
        final data = doc.data();
        targets.add({
          'vendorId': doc.id,
          'placeId': doc.id,
          'name':
              '${data['businessName'] ?? data['displayName'] ?? 'Heritage Vendor'}',
          'category': '${data['category'] ?? 'Heritage'}',
          'area': '${data['area'] ?? data['city'] ?? 'Malaysia'}',
        });
      }
    } catch (_) {}

    try {
      final placesSnapshot = await db.collection('places').get();
      for (final doc in placesSnapshot.docs) {
        final data = doc.data();
        targets.add({
          'vendorId': '${data['vendorId'] ?? ''}',
          'placeId': doc.id,
          'name': '${data['name'] ?? 'Cultural Heritage Stop'}',
          'category': '${data['category'] ?? 'Heritage'}',
          'area': '${data['area'] ?? 'Malaysia'}',
        });
      }
    } catch (_) {}

    int addedCount = 0;
    int targetIndex = 0;

    for (final target in targets) {
      final placeId = target['placeId'] as String;
      if (!force && existingPlaceIds.contains(placeId)) {
        continue;
      }

      final placeName = target['name'] as String;
      final category = target['category'] as String;
      final area = target['area'] as String;
      final vendorId = target['vendorId'] as String;
      final placeNameKey = placeName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final validSamples = [
        {
          'reviewerName': 'Tan Mei Ling',
          'rating': 5,
          'comment':
              'Exceptional experience! Authentic $category with top-quality service. Highly recommend visiting when in $area.',
          'daysAgo': 2,
        },
        {
          'reviewerName': 'Hafiz Ridzuan',
          'rating': 5,
          'comment':
              'One of the best $category spots in $area. Generous portions and very welcoming staff.',
          'daysAgo': 5,
        },
        {
          'reviewerName': 'Sarah Jenkins',
          'rating': 4,
          'comment':
              'Lovely cultural vibe and great attention to detail. Will definitely bring my friends here again.',
          'daysAgo': 12,
        },
      ];

      for (final sample in validSamples) {
        final date = DateTime.now().subtract(
          Duration(days: sample['daysAgo'] as int),
        );
        await reviewsCollection.add({
          'userId':
              'traveler_${(sample['reviewerName'] as String).toLowerCase().replaceAll(' ', '_')}',
          'reviewerName': sample['reviewerName'],
          'placeId': placeId,
          'vendorId': vendorId.isNotEmpty ? vendorId : null,
          'placeName': placeName,
          'placeNameKey': placeNameKey,
          'source': 'traveler_app',
          'rating': sample['rating'],
          'comment': sample['comment'],
          'status': 'valid',
          'flagReason': null,
          'flagReasons': const <String>[],
          'mlSentiment': 'positive',
          'mlSentimentConfidence': 0.95,
          'mlNegativeProbability': 0.02,
          'mlNeutralProbability': 0.03,
          'mlPositiveProbability': 0.95,
          'mlRatingMismatch': false,
          'mlSuspiciousProbability': 0.05,
          'mlDecision': 'valid',
          'mlModelVersion': 'MyHeritage-ML-v2.2',
          'createdAt': Timestamp.fromDate(date),
          'updatedAt': Timestamp.fromDate(date),
        });
        addedCount++;
      }

      // Add realistic flagged reviews on selected targets so the Admin side has a rich flagged review moderation queue!
      if (targetIndex % 3 == 0) {
        final date = DateTime.now().subtract(
          Duration(hours: 3 * (targetIndex + 1)),
        );
        await reviewsCollection.add({
          'userId': 'user_bot_${1000 + targetIndex}',
          'reviewerName': 'Crypto_Promoter_Bot',
          'placeId': placeId,
          'vendorId': vendorId.isNotEmpty ? vendorId : null,
          'placeName': placeName,
          'placeNameKey': placeNameKey,
          'source': 'traveler_app',
          'rating': 1,
          'comment':
              'CLAIM FREE BITCOIN & VOUCHER REWARDS AT HTTP://CRYPTO-PROMO-BONUS.XYZ/CLAIM BEST CASHBACK GUARANTEED!',
          'status': 'flagged',
          'flagReason':
              'Automated ML Flag: External promotional URL / Commercial solicitation spam',
          'flagReasons': [
            'Promotional spam link detected',
            'Commercial solicitation forbidden',
          ],
          'mlSentiment': 'neutral',
          'mlSentimentConfidence': 0.91,
          'mlNegativeProbability': 0.15,
          'mlNeutralProbability': 0.80,
          'mlPositiveProbability': 0.05,
          'mlRatingMismatch': false,
          'mlSuspiciousProbability': 0.98,
          'mlDecision': 'flagged',
          'mlModelVersion': 'MyHeritage-ML-v2.2',
          'createdAt': Timestamp.fromDate(date),
          'updatedAt': Timestamp.fromDate(date),
        });
        addedCount++;
      } else if (targetIndex % 3 == 1) {
        final date = DateTime.now().subtract(
          Duration(hours: 6 * (targetIndex + 1)),
        );
        await reviewsCollection.add({
          'userId': 'user_sus_${2000 + targetIndex}',
          'reviewerName': 'Alex Tan',
          'placeId': placeId,
          'vendorId': vendorId.isNotEmpty ? vendorId : null,
          'placeName': placeName,
          'placeNameKey': placeNameKey,
          'source': 'traveler_app',
          'rating': 1,
          'comment':
              'Outstanding heritage atmosphere, delicious specialty food and staff were exceptionally kind and polite! 10/10 best place!',
          'status': 'flagged',
          'flagReason':
              'Automated ML Flag: Rating mismatch (1-star rating given with intensely positive praising text)',
          'flagReasons': [
            'Severe rating-sentiment polarity contradiction (1-star vs 98% positive text)',
          ],
          'mlSentiment': 'positive',
          'mlSentimentConfidence': 0.98,
          'mlNegativeProbability': 0.01,
          'mlNeutralProbability': 0.01,
          'mlPositiveProbability': 0.98,
          'mlRatingMismatch': true,
          'mlSuspiciousProbability': 0.89,
          'mlDecision': 'flagged',
          'mlModelVersion': 'MyHeritage-ML-v2.2',
          'createdAt': Timestamp.fromDate(date),
          'updatedAt': Timestamp.fromDate(date),
        });
        addedCount++;
      }

      targetIndex++;
    }

    return addedCount;
  }
}
