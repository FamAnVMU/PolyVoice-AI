import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Handles military-grade AES-256-CBC encryption and PBKDF2-SHA256 key derivation
/// for PolyVoice AI backup exports and imports.
/// Author: FamAn
class BackupEncryptionHelper {
  static const int pbkdf2Iterations = 10000;
  static const int keyLength = 32; // 256-bit key
  static const int ivLength = 16;  // 128-bit block size

  /// Derives a 256-bit cryptographic key from password and salt using PBKDF2 with HMAC-SHA256.
  static Uint8List deriveKey(String password, Uint8List salt) {
    final passwordBytes = utf8.encode(password);
    final hmac = Hmac(sha256, passwordBytes);

    // Number of 32-byte blocks needed (1 block for 32 bytes)
    final numBlocks = (keyLength / 32).ceil();
    final result = BytesBuilder(copy: false);

    for (int block = 1; block <= numBlocks; block++) {
      // U1 = HMAC(password, salt || INT_32_BE(block))
      final blockBytes = Uint8List(4)..buffer.asByteData().setUint32(0, block, Endian.big);
      final saltAndBlock = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt)
        ..setRange(salt.length, salt.length + 4, blockBytes);

      var u = hmac.convert(saltAndBlock).bytes;
      var xorSum = List<int>.from(u);

      for (int iter = 1; iter < pbkdf2Iterations; iter++) {
        u = hmac.convert(u).bytes;
        for (int i = 0; i < xorSum.length; i++) {
          xorSum[i] ^= u[i];
        }
      }

      result.add(xorSum);
    }

    return Uint8List.fromList(result.toBytes().sublist(0, keyLength));
  }

  /// Encrypts raw JSON backup string with AES-256-CBC using user password.
  static String encryptBackup(String plaintextJson, String password) {
    // 1. Generate 16-byte cryptographically secure random salt and IV
    final rng = Random.secure();
    final salt = Uint8List.fromList(List<int>.generate(16, (_) => rng.nextInt(256)));
    final ivBytes = Uint8List.fromList(List<int>.generate(ivLength, (_) => rng.nextInt(256)));

    // 2. Derive 256-bit key from password
    final keyBytes = deriveKey(password, salt);

    // 3. Encrypt payload using AES-256-CBC with PKCS7 padding
    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));

    final encrypted = encrypter.encrypt(plaintextJson, iv: iv);

    // 4. Assemble standard encrypted envelope
    final envelope = {
      'polyvoice_encrypted_backup': true,
      'schema_version': 2,
      'algorithm': 'AES-256-CBC',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': pbkdf2Iterations,
      'salt_hex': salt.map((b) => b.toRadixString(16).padLeft(2, '0')).join(''),
      'iv_hex': ivBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(''),
      'ciphertext_b64': encrypted.base64,
    };

    return jsonEncode(envelope);
  }

  /// Decrypts an encrypted envelope using user password.
  static String decryptBackup(String payload, String password) {
    final Map<String, dynamic> envelope = jsonDecode(payload) as Map<String, dynamic>;
    if (envelope['polyvoice_encrypted_backup'] != true) {
      throw const FormatException('Tệp không phải là bản sao lưu mã hóa hợp lệ.');
    }

    final saltHex = envelope['salt_hex'] as String;
    final ivHex = envelope['iv_hex'] as String;
    final ciphertextB64 = envelope['ciphertext_b64'] as String;

    final salt = _hexToBytes(saltHex);
    final ivBytes = _hexToBytes(ivHex);

    // Derive same 256-bit key from password + salt
    final keyBytes = deriveKey(password, salt);

    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));

    final decrypted = encrypter.decrypt64(ciphertextB64, iv: iv);
    return decrypted;
  }

  /// Checks whether a given string is an encrypted backup envelope.
  static bool isEncryptedBackup(String payload) {
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> && decoded['polyvoice_encrypted_backup'] == true;
    } catch (_) {
      return false;
    }
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
