import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'helpers.dart';

class AccountProfile {
  const AccountProfile({required this.role, required this.data});

  final String role;
  final Map<String, dynamic> data;
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

  static Future<void> notify({
    required String userId,
    required String title,
    required String message,
    String type = 'general',
    String? referenceId,
    String? groupId,
    String? chatId,
  }) async {
    await db.collection('notifications').add({
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'referenceId': referenceId,

      if (groupId != null)
        'groupId': groupId,

      if (chatId != null)
        'chatId': chatId,

      'read': false,

      // ==========================================================
      // USED BY OUR SPARK NOTIFICATION SERVER
      // ==========================================================

      'pushStatus': 'pending',
      'pushAttempts': 0,

      'createdAt':
      FieldValue.serverTimestamp(),
    });
  }

  static Future<void> claimVoucher({
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
    final claimRef = db.collection('claimed_vouchers').doc('${uid}_$voucherId');

    await db.runTransaction((transaction) async {
      final travelerSnapshot = await transaction.get(travelerProfileRef);
      final voucherSnapshot = await transaction.get(voucherRef);
      final existingClaim = await transaction.get(claimRef);

      if (!travelerSnapshot.exists) {
        throw Exception('Traveler profile was not found.');
      }

      final traveler = travelerSnapshot.data()!;
      if (traveler['role'] != 'traveler') {
        throw Exception('Only travelers can claim vouchers.');
      }
      if (traveler['status'] != 'active') {
        throw Exception('This traveler account is not active.');
      }

      if (!voucherSnapshot.exists) {
        throw Exception('This voucher is no longer available.');
      }

      final currentVoucher = voucherSnapshot.data()!;
      final cost = (currentVoucher['pointCost'] as num?)?.toInt() ?? 0;
      final currentPoints = (traveler['points'] as num?)?.toInt() ?? 0;
      final inventory =
          (currentVoucher['inventoryRemaining'] as num?)?.toInt() ?? 0;

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

      final expiry = asDate(currentVoucher['expiresAt']);
      if (expiry != null && !expiry.isAfter(DateTime.now())) {
        throw Exception('This voucher has expired.');
      }

      if (inventory <= 0) {
        throw Exception('This reward is fully claimed.');
      }

      if (existingClaim.exists) {
        throw Exception('You already claimed this voucher.');
      }

      final vendorId = '${currentVoucher['vendorId'] ?? ''}'.trim();
      if (vendorId.isEmpty) {
        throw Exception('This voucher is not linked to a registered vendor.');
      }

      final vendorSnapshot = await transaction.get(vendorRef(vendorId));

      if (!vendorSnapshot.exists) {
        throw Exception('The vendor linked to this voucher was not found.');
      }

      final vendor = vendorSnapshot.data()!;
      if (vendor['status'] != 'active' ||
          vendor['vendorStatus'] != 'verified') {
        throw Exception('The vendor linked to this voucher is unavailable.');
      }

      final pointsAfterClaim = currentPoints - cost;
      final token = randomToken();

      transaction.update(travelerProfileRef, {
        'points': pointsAfterClaim,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(voucherRef, {
        'inventoryRemaining': inventory - 1,
        'claimCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(claimRef, {
        'travelerId': uid,
        'userId': uid,
        'voucherId': voucherId,
        'vendorId': vendorId,
        'vendorName':
            currentVoucher['vendorName'] ??
            vendor['businessName'] ??
            vendor['displayName'],
        'title': currentVoucher['title'],
        'pointCost': cost,
        'pointsBeforeClaim': currentPoints,
        'pointsAfterClaim': pointsAfterClaim,
        'token': token,
        'status': 'claimed',
        'claimedAt': FieldValue.serverTimestamp(),
        'expiresAt': currentVoucher['expiresAt'],
      });
    });
  }

  static Future<String> redeemClaim(String rawQr, String vendorId) async {
    final parts = rawQr.split('|');
    if (parts.length != 2) {
      throw Exception('Unrecognized QR code.');
    }

    final claimRef = db.collection('claimed_vouchers').doc(parts[0]);
    final redemptionRef = db.collection('redemptions').doc();
    String travelerId = '';

    await db.runTransaction((transaction) async {
      final claimSnapshot = await transaction.get(claimRef);
      if (!claimSnapshot.exists) {
        throw Exception('Voucher claim was not found.');
      }

      final claim = claimSnapshot.data()!;
      if (claim['token'] != parts[1]) {
        throw Exception('Invalid voucher token.');
      }
      if (claim['vendorId'] != vendorId) {
        throw Exception('This voucher belongs to another vendor.');
      }
      if (claim['status'] != 'claimed') {
        throw Exception('Voucher is already redeemed or unavailable.');
      }

      final expiry = asDate(claim['expiresAt']);
      if (expiry != null && expiry.isBefore(DateTime.now())) {
        throw Exception('Voucher has expired.');
      }

      travelerId = '${claim['travelerId'] ?? claim['userId'] ?? ''}';

      transaction.update(claimRef, {
        'status': 'redeemed',
        'redeemedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(redemptionRef, {
        'claimId': claimRef.id,
        'voucherId': claim['voucherId'],
        'vendorId': vendorId,
        'travelerId': travelerId,
        'redeemedAt': FieldValue.serverTimestamp(),
      });
    });

    await notify(
      userId: travelerId,
      title: 'Redemption successful',
      message: 'Your voucher was successfully redeemed.',
      type: 'voucher',
      referenceId: claimRef.id,
    );

    return claimRef.id;
  }
}
