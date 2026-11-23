import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-only settings. Everything that belongs to a user lives in Supabase;
/// this only keeps small things that are about this device.
class PreferencesService {
  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static const String _keyFirstLaunch = 'is_first_launch';
  static const String _keyPendingAvatarPrefix = 'pending_avatar_';

  bool get isFirstLaunch => _prefs.getBool(_keyFirstLaunch) ?? true;

  Future<void> setFirstLaunchCompleted() async {
    await _prefs.setBool(_keyFirstLaunch, false);
  }

  /// A profile photo chosen at sign-up is kept here until the account is
  /// approved (uploads are only allowed for approved accounts).
  Future<void> savePendingAvatar(String email, Uint8List bytes) async {
    await _prefs.setString(_pendingKey(email), base64Encode(bytes));
  }

  Uint8List? getPendingAvatar(String email) {
    final raw = _prefs.getString(_pendingKey(email));
    if (raw == null) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPendingAvatar(String email) async {
    await _prefs.remove(_pendingKey(email));
  }

  String _pendingKey(String email) => '$_keyPendingAvatarPrefix${email.trim().toLowerCase()}';
}
