from __future__ import annotations

from pathlib import Path
import re
import shutil
import sys

ROOT = Path.cwd()

COMPANION = ROOT / 'lib/traveler/companion/companion_page.dart'
GROUP_DETAILS = ROOT / 'lib/traveler/companion/group_details_page.dart'
JOIN_PAGE = ROOT / 'lib/traveler/companion/join_group_page.dart'
CREATE_PAGE = ROOT / 'lib/traveler/companion/create_group_page.dart'
TRAVELER_PAGES = ROOT / 'lib/traveler/traveler_pages.dart'
FUNCTIONS_INDEX = ROOT / 'functions/index.js'
FUNCTIONS_MODULE = ROOT / 'functions/companion_membership.js'
API_FILE = ROOT / 'lib/traveler/companion/companion_membership_api.dart'

REQUIRED = [COMPANION, GROUP_DETAILS, JOIN_PAGE, CREATE_PAGE, TRAVELER_PAGES, FUNCTIONS_INDEX]

API_CONTENT = r'''part of '../traveler_pages.dart';

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
'''

FUNCTIONS_CONTENT = r'''\'use strict\';

const { onRequest } = require('firebase-functions/v2/https');
const { getAuth } = require('firebase-admin/auth');
const {
  getFirestore,
  Timestamp,
  FieldValue,
} = require('firebase-admin/firestore');

const db = getFirestore();

function cleanText(value, maxLength = 160) {
  return String(value ?? '').trim().slice(0, maxLength);
}

function setCors(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
}

async function authenticateRequest(req) {
  const authorization = req.get('Authorization') || '';
  const match = authorization.match(/^Bearer\\s+(.+)$/i);

  if (!match) {
    const error = new Error('Please sign in first.');
    error.statusCode = 401;
    throw error;
  }

  try {
    return await getAuth().verifyIdToken(match[1]);
  } catch (_) {
    const error = new Error('Your login session is invalid. Please sign in again.');
    error.statusCode = 401;
    throw error;
  }
}

function sendError(res, error) {
  res.status(error.statusCode || 500).json({
    error: error.message || 'Unable to complete the request.',
  });
}

async function findTravelerByUid(uid) {
  const direct = await db.collection('travelers').doc(uid).get();
  if (direct.exists) {
    return { id: direct.id, data: direct.data() || {} };
  }

  const byUid = await db
    .collection('travelers')
    .where('uid', '==', uid)
    .limit(1)
    .get();

  if (byUid.empty) return null;
  return { id: byUid.docs[0].id, data: byUid.docs[0].data() || {} };
}

async function findTravelerByEmail(email) {
  const snapshot = await db
    .collection('travelers')
    .where('email', '==', email)
    .limit(5)
    .get();

  if (snapshot.empty) return null;

  const preferred = snapshot.docs.find((doc) => {
    const data = doc.data() || {};
    return data.role === 'traveler' && data.status === 'active';
  });

  const document = preferred || snapshot.docs[0];
  return { id: document.id, data: document.data() || {} };
}

function travelerUid(profile) {
  return cleanText(profile?.data?.uid || profile?.id, 200);
}

function travelerDisplayName(profile) {
  const data = profile?.data || {};
  return cleanText(
    data.displayName || data.fullName || data.name || data.email || 'Traveler',
    120,
  );
}

function validateTraveler(profile) {
  if (!profile) {
    const error = new Error('Traveler account was not found.');
    error.statusCode = 404;
    throw error;
  }

  if (profile.data.role !== 'traveler') {
    const error = new Error('Only traveler accounts can join a travel group.');
    error.statusCode = 403;
    throw error;
  }

  if (profile.data.status !== 'active') {
    const error = new Error('This traveler account is not active.');
    error.statusCode = 403;
    throw error;
  }
}

async function buildMemberNameUpdates(memberIds, extraProfiles = []) {
  const uniqueIds = [...new Set((memberIds || []).map((id) => cleanText(id, 200)).filter(Boolean))];
  const profiles = new Map();

  for (const profile of extraProfiles) {
    const uid = travelerUid(profile);
    if (uid) profiles.set(uid, profile);
  }

  await Promise.all(
    uniqueIds.map(async (uid) => {
      if (profiles.has(uid)) return;
      const profile = await findTravelerByUid(uid);
      if (profile) profiles.set(uid, profile);
    }),
  );

  const updates = {};
  for (const [uid, profile] of profiles.entries()) {
    const name = travelerDisplayName(profile);
    if (name) updates[`memberNames.${uid}`] = name;
  }
  return updates;
}

async function addNotification({ userId, title, message, type, referenceId }) {
  if (!userId) return;

  await db.collection('notifications').add({
    userId,
    title,
    message,
    type,
    referenceId,
    read: false,
    createdAt: Timestamp.now(),
  });
}

exports.addTravelGroupMemberByEmail = onRequest(
  {
    region: 'asia-southeast1',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (req, res) => {
    setCors(res);

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Only POST requests are supported.' });
      return;
    }

    try {
      const decoded = await authenticateRequest(req);
      const groupId = cleanText(req.body?.groupId, 200);
      const email = cleanText(req.body?.email, 320).toLowerCase();

      if (!groupId || !email || !email.includes('@')) {
        const error = new Error('Provide a valid travel group and Gmail/email address.');
        error.statusCode = 400;
        throw error;
      }

      const groupRef = db.collection('travel_groups').doc(groupId);
      const groupSnapshot = await groupRef.get();

      if (!groupSnapshot.exists) {
        const error = new Error('Travel group was not found.');
        error.statusCode = 404;
        throw error;
      }

      const group = groupSnapshot.data() || {};
      if (group.status !== 'active') {
        const error = new Error('This travel group is not active.');
        error.statusCode = 409;
        throw error;
      }
      if (group.leaderId !== decoded.uid) {
        const error = new Error('Only the group leader can add members by email.');
        error.statusCode = 403;
        throw error;
      }

      const memberProfile = await findTravelerByEmail(email);
      validateTraveler(memberProfile);

      const memberUid = travelerUid(memberProfile);
      const displayName = travelerDisplayName(memberProfile);
      if (!memberUid) {
        const error = new Error('The traveler account has no valid user ID.');
        error.statusCode = 409;
        throw error;
      }

      const currentMemberIds = Array.isArray(group.memberIds) ? group.memberIds : [];
      if (currentMemberIds.includes(memberUid)) {
        const error = new Error(`${displayName} is already a member of this group.`);
        error.statusCode = 409;
        throw error;
      }

      const allIds = [...currentMemberIds, memberUid];
      const nameUpdates = await buildMemberNameUpdates(allIds, [memberProfile]);

      await groupRef.update({
        memberIds: FieldValue.arrayUnion(memberUid),
        ...nameUpdates,
        updatedAt: Timestamp.now(),
      });

      await addNotification({
        userId: memberUid,
        title: 'Added to a travel group',
        message: `You were added to ${cleanText(group.name, 120) || 'a travel group'} by the group leader.`,
        type: 'companion_group',
        referenceId: groupId,
      });

      res.status(200).json({
        success: true,
        memberUid,
        displayName,
        groupId,
      });
    } catch (error) {
      sendError(res, error);
    }
  },
);

exports.joinTravelGroup = onRequest(
  {
    region: 'asia-southeast1',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (req, res) => {
    setCors(res);

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Only POST requests are supported.' });
      return;
    }

    try {
      const decoded = await authenticateRequest(req);
      const code = cleanText(req.body?.code, 20).toUpperCase();

      if (!code) {
        const error = new Error('Please enter a group code.');
        error.statusCode = 400;
        throw error;
      }

      const travelerProfile = await findTravelerByUid(decoded.uid);
      validateTraveler(travelerProfile);
      const displayName = travelerDisplayName(travelerProfile);

      const groupQuery = await db
        .collection('travel_groups')
        .where('code', '==', code)
        .limit(5)
        .get();

      const groupDocument = groupQuery.docs.find(
        (document) => document.data()?.status === 'active',
      );

      if (!groupDocument) {
        const error = new Error('Invalid or inactive group code.');
        error.statusCode = 404;
        throw error;
      }

      const groupRef = groupDocument.ref;
      const group = groupDocument.data() || {};
      const currentMemberIds = Array.isArray(group.memberIds) ? group.memberIds : [];
      const alreadyMember = currentMemberIds.includes(decoded.uid);

      const allIds = alreadyMember
        ? currentMemberIds
        : [...currentMemberIds, decoded.uid];
      const nameUpdates = await buildMemberNameUpdates(allIds, [travelerProfile]);

      await groupRef.update({
        memberIds: FieldValue.arrayUnion(decoded.uid),
        ...nameUpdates,
        updatedAt: Timestamp.now(),
      });

      if (!alreadyMember && group.leaderId && group.leaderId !== decoded.uid) {
        await addNotification({
          userId: group.leaderId,
          title: 'New travel group member',
          message: `${displayName} joined ${cleanText(group.name, 120) || 'your travel group'} using the group code.`,
          type: 'companion_group',
          referenceId: groupDocument.id,
        });
      }

      res.status(200).json({
        success: true,
        alreadyMember,
        groupId: groupDocument.id,
        groupName: cleanText(group.name, 120) || 'Travel Group',
        code,
        displayName,
      });
    } catch (error) {
      sendError(res, error);
    }
  },
);
'''

NEW_JOIN_METHOD = r'''  Future<void> joinGroup(BuildContext context) async {
    final codeController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join Travel Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the group code shared by the group leader.',
              style: TextStyle(color: ExplorerColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Group Code',
                hintText: 'ABC123',
                prefixIcon: Icon(Icons.key_outlined),
              ),
              onSubmitted: (_) => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.login),
            label: const Text('Join Group'),
          ),
        ],
      ),
    );

    final code = codeController.text.trim().toUpperCase();
    codeController.dispose();

    if (confirmed != true) return;

    if (code.isEmpty) {
      if (context.mounted) {
        showMessage(context, 'Please enter a group code.', error: true);
      }
      return;
    }

    try {
      final result = await CompanionMembershipApi.joinGroup(code: code);
      final groupName = '${result['groupName'] ?? 'travel group'}';
      final alreadyMember = result['alreadyMember'] == true;

      if (context.mounted) {
        showMessage(
          context,
          alreadyMember
              ? 'You are already a member of $groupName. Member details were refreshed.'
              : 'Joined $groupName successfully.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        showMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    }
  }
'''

NEW_ADD_METHOD = r'''  Future<void> addMember(Map<String, dynamic> group) async {
    final uid = AppServices.auth.currentUser?.uid;

    if (uid == null || '${group['leaderId'] ?? ''}' != uid) {
      if (mounted) {
        showMessage(
          context,
          'Only the group leader can add members.',
          error: true,
        );
      }
      return;
    }

    final normalizedEmail = await _askForMemberEmail();

    if (!mounted ||
        normalizedEmail == null ||
        normalizedEmail.trim().isEmpty) {
      return;
    }

    setState(() => addingMember = true);

    try {
      final result = await CompanionMembershipApi.addMemberByEmail(
        groupId: widget.groupId,
        email: normalizedEmail,
      );

      final displayName =
          '${result['displayName'] ?? normalizedEmail}'.trim();

      if (mounted) {
        showMessage(context, '$displayName was added.');
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => addingMember = false);
    }
  }
'''

NEW_JOIN_PAGE_SUBMIT = r'''  Future<void> _submit() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) {
      showMessage(context, 'Please enter a group code.', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await CompanionMembershipApi.joinGroup(code: code);
      final groupName = '${result['groupName'] ?? 'travel group'}';
      final alreadyMember = result['alreadyMember'] == true;

      if (mounted) {
        showMessage(
          context,
          alreadyMember
              ? 'You are already a member of $groupName. Member details were refreshed.'
              : 'Joined $groupName successfully.',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
'''


def fail(message: str) -> None:
    print(f'ERROR: {message}')
    sys.exit(1)


def backup(path: Path) -> None:
    backup_root = ROOT.parent / f'{ROOT.name}_companion_fix_backups'
    relative = path.relative_to(ROOT)
    backup_path = backup_root / relative
    backup_path.parent.mkdir(parents=True, exist_ok=True)
    if not backup_path.exists():
        shutil.copy2(path, backup_path)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        fail(f'Could not find expected {label} block in local file. Your branch may differ from OWK.')
    return text.replace(old, new, 1)


def regex_replace_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count == 0:
        if replacement.strip() in text:
            return text
        fail(f'Could not find expected {label} block in local file. Your branch may differ from OWK.')
    return updated


for path in REQUIRED:
    if not path.exists():
        fail(f'Missing {path}. Run this script from the myheritage-explorer repository root.')

for path in REQUIRED:
    backup(path)

# 1) New client API part file.
API_FILE.parent.mkdir(parents=True, exist_ok=True)
API_FILE.write_text(API_CONTENT, encoding='utf-8')

# 2) Register the new part in traveler_pages.dart.
text = TRAVELER_PAGES.read_text(encoding='utf-8-sig')
part_line = "part 'companion/companion_membership_api.dart';"
if part_line not in text:
    text = replace_once(
        text,
        "part 'companion/companion_page.dart';",
        "part 'companion/companion_page.dart';\n" + part_line,
        'companion_page part declaration',
    )
TRAVELER_PAGES.write_text(text, encoding='utf-8')

# 3) Patch CompanionPage group creation + join-by-code.
text = COMPANION.read_text(encoding='utf-8')
if 'leaderDisplayName' not in text:
    text = replace_once(
        text,
        """      final code = await _createUniqueGroupCode();\n\n      await AppServices.db.collection('travel_groups').add({""",
        """      final code = await _createUniqueGroupCode();\n      final leaderProfile = await AppServices.travelerRef(user.uid).get();\n      final leaderData = leaderProfile.data() ?? const <String, dynamic>{};\n      final leaderDisplayName =\n          '${leaderData['displayName'] ?? user.displayName ?? user.email?.split('@').first ?? 'Group Leader'}'\n              .trim();\n\n      await AppServices.db.collection('travel_groups').add({""",
        'createGroup profile lookup',
    )
    text = replace_once(
        text,
        """        'memberIds': [user.uid],\n        'status': 'active',""",
        """        'memberIds': [user.uid],\n        'memberNames': {user.uid: leaderDisplayName},\n        'status': 'active',""",
        'createGroup memberNames',
    )

text = regex_replace_once(
    text,
    r"  Future<void> joinGroup\(BuildContext context\) async \{.*?\n  \}\n\n  Future<String> _displayName",
    NEW_JOIN_METHOD + "\n  Future<String> _displayName",
    'CompanionPage.joinGroup',
)
COMPANION.write_text(text, encoding='utf-8')

# 4) Patch the alternate CreateGroupPage too, so either UI creates memberNames.
text = CREATE_PAGE.read_text(encoding='utf-8')
if 'leaderDisplayName' not in text:
    text = replace_once(
        text,
        """      final uid = AppServices.auth.currentUser!.uid;\n      final code = randomCode().toUpperCase();\n\n      final docRef = await AppServices.db.collection('travel_groups').add({""",
        """      final user = AppServices.auth.currentUser!;\n      final uid = user.uid;\n      final code = randomCode().toUpperCase();\n      final leaderProfile = await AppServices.travelerRef(uid).get();\n      final leaderData = leaderProfile.data() ?? const <String, dynamic>{};\n      final leaderDisplayName =\n          '${leaderData['displayName'] ?? user.displayName ?? user.email?.split('@').first ?? 'Group Leader'}'\n              .trim();\n\n      final docRef = await AppServices.db.collection('travel_groups').add({""",
        'CreateGroupPage profile lookup',
    )
    text = replace_once(
        text,
        """        'memberIds': [uid],\n        'status': 'active',""",
        """        'memberIds': [uid],\n        'memberNames': {uid: leaderDisplayName},\n        'status': 'active',""",
        'CreateGroupPage memberNames',
    )
CREATE_PAGE.write_text(text, encoding='utf-8')

# 5) Patch the alternate JoinGroupPage.
text = JOIN_PAGE.read_text(encoding='utf-8')
text = regex_replace_once(
    text,
    r"  Future<void> _submit\(\) async \{.*?\n  \}\n\n  @override\n  void dispose",
    NEW_JOIN_PAGE_SUBMIT + "\n  @override\n  void dispose",
    'JoinGroupPage._submit',
)
JOIN_PAGE.write_text(text, encoding='utf-8')

# 6) Patch GroupDetailsPage add-member and cached member names.
text = GROUP_DETAILS.read_text(encoding='utf-8')
text = regex_replace_once(
    text,
    r"  Future<void> addMember\(Map<String, dynamic> group\) async \{.*?\n  \}\n\n  Future<void> removeMember\(",
    NEW_ADD_METHOD + "\n  Future<void> removeMember(",
    'GroupDetailsPage.addMember',
)

if "final memberNames = Map<String, dynamic>.from(\n      group['memberNames']" not in text:
    text = replace_once(
        text,
        """    final memberName = await _displayName(memberId);\n    final memberUid = await _resolveTravelerUid(memberId);""",
        """    final memberNames = Map<String, dynamic>.from(\n      group['memberNames'] ?? const <String, dynamic>{},\n    );\n    final cachedName = '${memberNames[memberId] ?? ''}'.trim();\n    final memberName =\n        cachedName.isNotEmpty ? cachedName : await _displayName(memberId);\n    final memberUid = await _resolveTravelerUid(memberId);""",
        'removeMember cached name',
    )

if "'memberNames.$memberId': FieldValue.delete()" not in text:
    text = replace_once(
        text,
        """      await _groupRef.update({\n        'memberIds': FieldValue.arrayRemove([memberId]),\n        'updatedAt': FieldValue.serverTimestamp(),\n      });""",
        """      await _groupRef.update({\n        'memberIds': FieldValue.arrayRemove([memberId]),\n        'memberNames.$memberId': FieldValue.delete(),\n        if (memberUid != memberId)\n          'memberNames.$memberUid': FieldValue.delete(),\n        'updatedAt': FieldValue.serverTimestamp(),\n      });""",
        'removeMember cache cleanup',
    )

# Add memberNames map only inside _buildMembersTab.
member_tab_pattern = r"(  Widget _buildMembersTab\(.*?final memberIds = List<String>\.from\(\n      group\['memberIds'\] \?\? const <String>\[],\n    \);)"
match = re.search(member_tab_pattern, text, flags=re.S)
if not match:
    fail('Could not locate _buildMembersTab memberIds block.')
if "group['memberNames']" not in match.group(1):
    replacement = match.group(1) + "\n    final memberNames = Map<String, dynamic>.from(\n      group['memberNames'] ?? const <String, dynamic>{},\n    );"
    text = text[:match.start()] + replacement + text[match.end():]

old_member_start = """        ...memberIds.map(\n              (memberId) => FutureBuilder<String>(\n            key: ValueKey('travel-group-member-$memberId'),\n            future: _displayName(memberId),"""
new_member_start = """        ...memberIds.map(\n              (memberId) {\n            final cachedName = '${memberNames[memberId] ?? ''}'.trim();\n\n            return FutureBuilder<String>(\n              key: ValueKey('travel-group-member-$memberId'),\n              future: cachedName.isNotEmpty\n                  ? Future<String>.value(cachedName)\n                  : _displayName(memberId),"""
if old_member_start in text:
    text = text.replace(old_member_start, new_member_start, 1)
    close_marker = """            },\n          ),\n        ),\n      ],\n    );\n  }\n\n  Widget _buildSosTab("""
    close_replacement = """            },\n          );\n        },\n      ),\n      ],\n    );\n  }\n\n  Widget _buildSosTab("""
    text = replace_once(text, close_marker, close_replacement, 'memberNames map callback close')

# Prefer cached member name in SOS map card too.
old_map_name = """                          child: FutureBuilder<String>(\n                            future: _displayName(document.id),"""
new_map_name = """                          child: FutureBuilder<String>(\n                            future: (() {\n                              final names = Map<String, dynamic>.from(\n                                group['memberNames'] ??\n                                    const <String, dynamic>{},\n                              );\n                              final cached =\n                                  '${names[document.id] ?? ''}'.trim();\n                              return cached.isNotEmpty\n                                  ? Future<String>.value(cached)\n                                  : _displayName(document.id);\n                            })(),"""
if old_map_name in text:
    text = text.replace(old_map_name, new_map_name, 1)

GROUP_DETAILS.write_text(text, encoding='utf-8')

# 7) Add authenticated server functions.
FUNCTIONS_MODULE.write_text(FUNCTIONS_CONTENT.replace("\\'use strict\\';", "'use strict';"), encoding='utf-8')

text = FUNCTIONS_INDEX.read_text(encoding='utf-8')
export_marker = "const companionMembership = require('./companion_membership');"
if export_marker not in text:
    text = text.rstrip() + "\n\n// Companion group membership operations run on the trusted backend so\n// clients do not need permission to read another traveler's private profile.\nconst companionMembership = require('./companion_membership');\nexports.addTravelGroupMemberByEmail =\n  companionMembership.addTravelGroupMemberByEmail;\nexports.joinTravelGroup = companionMembership.joinTravelGroup;\n"
FUNCTIONS_INDEX.write_text(text, encoding='utf-8')

print('Companion membership fix applied successfully.')
print('Next commands:')
print('  flutter clean')
print('  flutter pub get')
print('  flutter analyze')
print('  firebase deploy --project myheritage-4fe2f --only "functions:addTravelGroupMemberByEmail,functions:joinTravelGroup"')
print('  flutter run')
