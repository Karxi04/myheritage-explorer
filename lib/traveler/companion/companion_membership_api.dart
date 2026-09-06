part of '../traveler_pages.dart';

class CompanionMembershipApi {
  const CompanionMembershipApi._();

  static const String _baseUrl =
      'https://asia-southeast1-myheritage-4fe2f.cloudfunctions.net';

  static Future<Map<String, dynamic>> _post(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final user = AppServices.auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in first.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Unable to verify your login session. Please sign in again.');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/$functionName'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    Map<String, dynamic> data = const <String, dynamic>{};
    if (response.body.trim().isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      } else if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        '${data['error'] ?? 'Unable to complete the group request.'}',
      );
    }

    return data;
  }

  static Future<Map<String, dynamic>> addMemberByEmail({
    required String groupId,
    required String email,
  }) {
    return _post(
      'addTravelGroupMemberByEmail',
      {
        'groupId': groupId,
        'email': email.trim().toLowerCase(),
      },
    );
  }

  static Future<Map<String, dynamic>> joinGroup({
    required String code,
  }) {
    return _post(
      'joinTravelGroup',
      {
        'code': code.trim().toUpperCase(),
      },
    );
  }
}
