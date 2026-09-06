import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services.dart';

class MalaysianStateItem {
  const MalaysianStateItem({
    required this.id,
    required this.name,
    required this.areas,
    this.isActive = true,
  });

  final String id;
  final String name;
  final List<String> areas;
  final bool isActive;

  factory MalaysianStateItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawAreas = data['areas'];
    final List<String> areaList = [];
    if (rawAreas is List) {
      for (final a in rawAreas) {
        if (a != null && a.toString().trim().isNotEmpty) {
          areaList.add(a.toString().trim());
        }
      }
    }
    return MalaysianStateItem(
      id: doc.id,
      name: '${data['name'] ?? doc.id}',
      areas: areaList.isNotEmpty ? areaList : _fallbackAreas(doc.id),
      isActive: data['isActive'] != false,
    );
  }

  static List<String> _fallbackAreas(String stateId) {
    return MalaysiaLocationService.defaultStates
        .firstWhere((s) => s.id == stateId, orElse: () => const MalaysianStateItem(id: '', name: '', areas: []))
        .areas;
  }
}

class MalaysiaLocationService {
  static const List<MalaysianStateItem> defaultStates = [
    MalaysianStateItem(
      id: 'penang',
      name: 'Penang',
      areas: [
        'George Town',
        'Batu Ferringhi',
        'Bayan Lepas',
        'Balik Pulau',
        'Bukit Mertajam',
        'Butterworth',
        'Seberang Jaya',
        'Tanjung Bungah',
        'Teluk Bahang',
        'Nibong Tebal',
      ],
    ),
    MalaysianStateItem(
      id: 'melaka',
      name: 'Melaka',
      areas: [
        'Melaka City (Bandar Hilir)',
        'Jonker Walk & Heritage Core',
        'Ayer Keroh',
        'Klebang',
        'Alor Gajah',
        'Jasin',
        'Masjid Tanah',
      ],
    ),
    MalaysianStateItem(
      id: 'kuala_lumpur',
      name: 'Kuala Lumpur',
      areas: [
        'Bukit Bintang',
        'KLCC & City Centre',
        'Chinatown / Petaling Street',
        'Brickfields (Little India)',
        'Bangsar',
        'Mont Kiara',
        'Chow Kit & Kampung Baru',
        'Cheras',
        'Kepong',
      ],
    ),
    MalaysianStateItem(
      id: 'selangor',
      name: 'Selangor',
      areas: [
        'Petaling Jaya',
        'Shah Alam',
        'Subang Jaya',
        'Klang',
        'Cyberjaya',
        'Kajang',
        'Kuala Selangor',
        'Sepang',
        'Rawang',
      ],
    ),
    MalaysianStateItem(
      id: 'perak',
      name: 'Perak',
      areas: [
        'Ipoh Old Town',
        'Ipoh New Town',
        'Taiping',
        'Teluk Intan',
        'Kuala Kangsar',
        'Batu Gajah',
        'Pangkor Island / Lumut',
        'Gopeng',
        'Kampar',
      ],
    ),
    MalaysianStateItem(
      id: 'johor',
      name: 'Johor',
      areas: [
        'Johor Bahru City',
        'Muar',
        'Batu Pahat',
        'Kluang',
        'Kota Tinggi',
        'Iskandar Puteri',
        'Pontian',
        'Mersing',
      ],
    ),
    MalaysianStateItem(
      id: 'kedah',
      name: 'Kedah',
      areas: [
        'Alor Setar',
        'Langkawi (Kuah & Cenang)',
        'Sungai Petani',
        'Kulim',
        'Baling',
        'Kuala Kedah',
      ],
    ),
    MalaysianStateItem(
      id: 'pahang',
      name: 'Pahang',
      areas: [
        'Kuantan',
        'Cameron Highlands',
        'Bentong',
        'Fraser\'s Hill',
        'Cherating',
        'Temerloh',
        'Raub',
      ],
    ),
    MalaysianStateItem(
      id: 'terengganu',
      name: 'Terengganu',
      areas: [
        'Kuala Terengganu',
        'Chinatown (Kampung Cina)',
        'Redang Island',
        'Perhentian Islands',
        'Marang',
        'Dungun',
        'Kemaman',
      ],
    ),
    MalaysianStateItem(
      id: 'kelantan',
      name: 'Kelantan',
      areas: [
        'Kota Bharu',
        'Tumpat',
        'Bachok',
        'Pasir Mas',
        'Tanah Merah',
        'Gua Musang',
      ],
    ),
    MalaysianStateItem(
      id: 'negeri_sembilan',
      name: 'Negeri Sembilan',
      areas: [
        'Seremban',
        'Port Dickson',
        'Nilai',
        'Rembau',
        'Kuala Pilah',
      ],
    ),
    MalaysianStateItem(
      id: 'perlis',
      name: 'Perlis',
      areas: [
        'Kangar',
        'Arau',
        'Kuala Perlis',
        'Padang Besar',
      ],
    ),
    MalaysianStateItem(
      id: 'sabah',
      name: 'Sabah',
      areas: [
        'Kota Kinabalu',
        'Kundasang & Ranau',
        'Sandakan',
        'Semporna',
        'Tawau',
        'Kudat',
      ],
    ),
    MalaysianStateItem(
      id: 'sarawak',
      name: 'Sarawak',
      areas: [
        'Kuching Waterfront & Old Town',
        'Miri',
        'Sibu',
        'Bintulu',
        'Bau & Wind Caves',
        'Damai Peninsula',
      ],
    ),
    MalaysianStateItem(
      id: 'putrajaya',
      name: 'Putrajaya',
      areas: [
        'Precinct 1 & Government Core',
        'Precinct 2 & 3 Waterfront',
        'Precinct 4 & Boulevard',
        'Putrajaya Lake & Botanical Park',
      ],
    ),
    MalaysianStateItem(
      id: 'labuan',
      name: 'Labuan',
      areas: [
        'Victoria Town',
        'Financial Park',
        'Labuan War Memorial & Beach',
      ],
    ),
  ];

  static List<MalaysianStateItem>? _cachedStates;

  /// Fetch states from Firestore 'states' collection if available, falling back to defaultStates
  static Future<List<MalaysianStateItem>> getStates() async {
    if (_cachedStates != null && _cachedStates!.isNotEmpty) {
      return _cachedStates!;
    }

    try {
      final snap = await AppServices.db.collection('states').get();
      if (snap.docs.isNotEmpty) {
        final list = snap.docs
            .map((doc) => MalaysianStateItem.fromFirestore(doc))
            .where((s) => s.isActive)
            .toList();
        if (list.isNotEmpty) {
          _cachedStates = list;
          return list;
        }
      }
    } catch (_) {
      // Fallback cleanly to defaultStates
    }

    _cachedStates = defaultStates;
    return defaultStates;
  }

  /// Get list of areas for a selected state
  static Future<List<String>> getAreasForState(String stateId) async {
    final states = await getStates();
    final match = states.firstWhere(
      (s) => s.id.toLowerCase() == stateId.toLowerCase() || s.name.toLowerCase() == stateId.toLowerCase(),
      orElse: () => defaultStates.first,
    );
    return match.areas;
  }

  /// Validate if a given area belongs to a state
  static bool isAreaInState(String area, String stateId) {
    final targetState = defaultStates.firstWhere(
      (s) => s.id.toLowerCase() == stateId.toLowerCase() || s.name.toLowerCase() == stateId.toLowerCase(),
      orElse: () => const MalaysianStateItem(id: '', name: '', areas: []),
    );
    if (targetState.areas.isEmpty) return true;
    final areaLower = area.toLowerCase().trim();
    return targetState.areas.any((a) =>
        areaLower.contains(a.toLowerCase()) || a.toLowerCase().contains(areaLower));
  }

  /// Normalize state name or state id into canonical state id (e.g. "Penang" -> "penang", "Kuala Lumpur" -> "kuala_lumpur")
  static String normalizeStateId(String state) {
    final lower = state.toLowerCase().trim().replaceAll(' ', '_').replaceAll('-', '_');
    if (lower.isEmpty) return 'penang';
    if (lower.contains('penang') || lower.contains('pinang')) return 'penang';
    if (lower.contains('melaka') || lower.contains('malacca')) return 'melaka';
    if (lower.contains('kuala_lumpur') || lower == 'kl' || lower.contains('lumpur')) return 'kuala_lumpur';
    if (lower.contains('selangor')) return 'selangor';
    if (lower.contains('perak')) return 'perak';
    if (lower.contains('johor')) return 'johor';
    if (lower.contains('kedah')) return 'kedah';
    if (lower.contains('pahang')) return 'pahang';
    if (lower.contains('terengganu')) return 'terengganu';
    if (lower.contains('kelantan')) return 'kelantan';
    if (lower.contains('sembilan')) return 'negeri_sembilan';
    if (lower.contains('perlis')) return 'perlis';
    if (lower.contains('sabah')) return 'sabah';
    if (lower.contains('sarawak')) return 'sarawak';
    if (lower.contains('putrajaya')) return 'putrajaya';
    if (lower.contains('labuan')) return 'labuan';

    for (final s in defaultStates) {
      if (s.id == lower || s.name.toLowerCase() == state.toLowerCase().trim()) {
        return s.id;
      }
    }
    return lower;
  }

  /// Infer state id from an area or address string
  static String inferStateIdFromArea(String area) {
    final lower = area.toLowerCase().trim();
    if (lower.isEmpty) return 'penang';

    // First check exact matches with known areas across defaultStates
    for (final s in defaultStates) {
      for (final a in s.areas) {
        final aLower = a.toLowerCase();
        if (lower.contains(aLower) || aLower.contains(lower)) {
          return s.id;
        }
      }
    }

    if (lower.contains('penang') || lower.contains('pulau pinang') || lower.contains('george town') || lower.contains('butterworth') || lower.contains('bukit mertajam')) {
      return 'penang';
    }
    if (lower.contains('melaka') || lower.contains('malacca') || lower.contains('ayer keroh') || lower.contains('jonker') || lower.contains('bandar hilir')) {
      return 'melaka';
    }
    if (lower.contains('kuala lumpur') || lower.contains('kl') || lower.contains('bukit bintang') || lower.contains('brickfields') || lower.contains('klcc') || lower.contains('petaling street')) {
      return 'kuala_lumpur';
    }
    if (lower.contains('selangor') || lower.contains('petaling jaya') || lower.contains('shah alam') || lower.contains('klang') || lower.contains('subang')) {
      return 'selangor';
    }
    if (lower.contains('perak') || lower.contains('ipoh') || lower.contains('taiping')) {
      return 'perak';
    }
    if (lower.contains('johor') || lower.contains('johor bahru') || lower.contains('muar')) {
      return 'johor';
    }
    if (lower.contains('kedah') || lower.contains('alor setar') || lower.contains('langkawi')) {
      return 'kedah';
    }
    if (lower.contains('pahang') || lower.contains('kuantan') || lower.contains('cameron')) {
      return 'pahang';
    }
    if (lower.contains('terengganu') || lower.contains('kuala terengganu')) {
      return 'terengganu';
    }
    if (lower.contains('kelantan') || lower.contains('kota bharu')) {
      return 'kelantan';
    }
    if (lower.contains('sembilan') || lower.contains('seremban') || lower.contains('port dickson')) {
      return 'negeri_sembilan';
    }
    if (lower.contains('perlis') || lower.contains('kangar')) {
      return 'perlis';
    }
    if (lower.contains('sabah') || lower.contains('kota kinabalu') || lower.contains('sandakan')) {
      return 'sabah';
    }
    if (lower.contains('sarawak') || lower.contains('kuching') || lower.contains('miri')) {
      return 'sarawak';
    }
    return 'penang';
  }

  /// Normalize state name
  static String getStateName(String stateId) {
    final normId = normalizeStateId(stateId);
    final match = defaultStates.firstWhere(
      (s) => s.id.toLowerCase() == normId.toLowerCase() || s.name.toLowerCase() == stateId.toLowerCase().trim(),
      orElse: () => MalaysianStateItem(id: stateId, name: stateId, areas: const []),
    );
    return match.name;
  }

  /// Clear in-memory cache
  static void clearCache() {
    _cachedStates = null;
  }
}
