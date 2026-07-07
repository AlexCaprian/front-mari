import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage._internal();

  static final TokenStorage instance = TokenStorage._internal();

  static const _tokenKey = 'auth_token';
  static const _expiresAtKey = 'auth_token_expires_at';

  // Keystore (Android), Keychain (iOS/macOS), DPAPI (Windows) e libsecret
  // (Linux) via os backends padrão do plugin em cada plataforma.
  final _storage = const FlutterSecureStorage();

  Future<void> save(String token, {DateTime? expiresAt}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(
      key: _expiresAtKey,
      value: expiresAt?.toIso8601String(),
    );
  }

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<DateTime?> readExpiresAt() async {
    final raw = await _storage.read(key: _expiresAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiresAtKey);
  }
}
