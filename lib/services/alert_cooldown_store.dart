import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Single persisted cooldown record for a hazard alert.
class AlertCooldownEntry {
  const AlertCooldownEntry({required this.timestamp, this.priority});

  final DateTime timestamp;
  final double? priority;
}

/// Persists per-hazard alert cooldown state across app restarts.
///
/// Stores per-hazard last-alert timestamp and priority score under a single
/// JSON key in SharedPreferences. Precise location is never stored.
///
/// Fully backward-compatible with legacy entries containing only an ISO timestamp.
class AlertCooldownStore {
  const AlertCooldownStore({SharedPreferences? prefs}) : _prefs = prefs;

  /// Injectable [SharedPreferences] instance; uses the default singleton when
  /// null. Provide a concrete instance in tests to avoid async initialization.
  final SharedPreferences? _prefs;

  static const _key = 'safety_alert_cooldowns';

  Future<SharedPreferences> _store() async =>
      _prefs ?? await SharedPreferences.getInstance();

  Future<Map<String, AlertCooldownEntry>> _load() async {
    try {
      final store = await _store();
      await store.reload();
      final raw = store.getString(_key);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, AlertCooldownEntry>{};
      for (final entry in decoded.entries) {
        final val = entry.value;
        if (val is String) {
          // Legacy format: raw ISO string.
          final ts = DateTime.tryParse(val);
          if (ts != null) {
            result[entry.key] = AlertCooldownEntry(timestamp: ts);
          }
        } else if (val is Map<String, dynamic>) {
          // New format: Map with timestamp and optional priority.
          final tsStr = val['timestamp'] as String? ?? '';
          final ts = DateTime.tryParse(tsStr);
          final priority = (val['priority'] as num?)?.toDouble();
          if (ts != null) {
            result[entry.key] = AlertCooldownEntry(
              timestamp: ts,
              priority: priority,
            );
          }
        }
      }
      return result;
    } catch (_) {
      // Corrupted state: fail safely with an empty map.
      return {};
    }
  }

  Future<void> _save(Map<String, AlertCooldownEntry> map) async {
    try {
      final encoded = jsonEncode(
        map.map(
          (id, entry) => MapEntry(id, {
            'timestamp': entry.timestamp.toIso8601String(),
            if (entry.priority != null) 'priority': entry.priority,
          }),
        ),
      );
      await (await _store()).setString(_key, encoded);
    } catch (_) {}
  }

  /// Returns all stored entries with timestamps and priorities.
  Future<Map<String, AlertCooldownEntry>> loadEntries() => _load();

  /// Returns all currently stored cooldown timestamps (backward-compatible).
  Future<Map<String, DateTime>> loadAll() async {
    final entries = await _load();
    return entries.map((k, v) => MapEntry(k, v.timestamp));
  }

  /// Returns all currently stored cooldown priorities where known.
  Future<Map<String, double>> loadPriorities() async {
    final entries = await _load();
    final result = <String, double>{};
    for (final e in entries.entries) {
      if (e.value.priority != null) {
        result[e.key] = e.value.priority!;
      }
    }
    return result;
  }

  /// Records that [hazardId] was alerted at [now] with an optional [priority].
  Future<void> recordAlert(
    String hazardId, {
    DateTime? now,
    double? priority,
  }) async {
    final map = await _load();
    map[hazardId] = AlertCooldownEntry(
      timestamp: now ?? DateTime.now(),
      priority: priority,
    );
    await _save(map);
  }

  /// Removes cooldown entries for hazard IDs no longer in [activeIds],
  /// preventing unbounded growth.
  Future<void> pruneInactive(Set<String> activeIds) async {
    final map = await _load();
    map.removeWhere((id, _) => !activeIds.contains(id));
    await _save(map);
  }

  /// Clears all stored cooldown state. Used in tests.
  Future<void> clearAll() async {
    try {
      await (await _store()).remove(_key);
    } catch (_) {}
  }
}
