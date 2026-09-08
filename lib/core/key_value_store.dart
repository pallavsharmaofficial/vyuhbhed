import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The small slice of key–value storage Saath actually uses.
///
/// This exists for two reasons:
///
/// * `SharedPreferences.getInstance()` can fail (a corrupt store, a full disk,
///   a platform channel that never answers). An app whose job includes putting
///   helpline numbers in front of someone must still start when that happens,
///   so [InMemoryStore] takes over — settings are lost for the session, the app
///   is not.
/// * Tests get a real store without a mock platform channel.
abstract class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);

  bool? getBool(String key);
  Future<void> setBool(String key, bool value);

  Future<void> remove(String key);
}

class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);

  /// Opens the platform store, falling back to memory rather than failing to
  /// launch. Returns the store and whether persistence is actually working, so
  /// the caller can report the degradation instead of silently losing writes.
  static Future<(KeyValueStore, bool)> open() async {
    try {
      return (
        SharedPreferencesStore(await SharedPreferences.getInstance()),
        true
      );
    } on Object catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'saath',
        context: ErrorDescription('opening SharedPreferences'),
      ));
      return (InMemoryStore(), false);
    }
  }
}

class InMemoryStore implements KeyValueStore {
  InMemoryStore([Map<String, Object>? initial]) : _values = {...?initial};

  final Map<String, Object> _values;

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  bool? getBool(String key) => _values[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
