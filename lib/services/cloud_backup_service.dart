import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'storage_service.dart';

// SQLite's fixed 16-byte file header — every pre-envelope backup (format
// version 0, just the raw db file encrypted) starts with this. Used to tell
// an old-format backup apart from a new-format JSON envelope without
// needing a version byte that old backups never had.
const List<int> _sqliteMagic = [
  0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66, //
  0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
];

const int _saltLength = 16;
const int _nonceLength = 12;
const int _macLength = 16;

/// Storage path a backup for [passphrase] lives at — a one-way hash of the
/// passphrase, so the path itself never reveals or lets anyone guess the
/// passphrase, and two different users never collide on the same object
/// unless they picked the same passphrase. No I/O beyond the hash itself,
/// so it's plain testable.
Future<String> storagePathFor(String passphrase) async {
  final digest = await Sha256().hash(utf8.encode(passphrase));
  final hex = digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return 'backups/$hex.enc';
}

Future<SecretKey> _deriveKey(String passphrase, List<int> salt) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 200000,
    bits: 256,
  );
  return pbkdf2.deriveKeyFromPassword(password: passphrase, nonce: salt);
}

/// Builds the format-version-1 envelope: the db file and the backed-up
/// SharedPreferences keys, JSON-encoded. Pure/no I/O — see
/// test/cloud_backup_service_test.dart.
List<int> encodeBackupEnvelope({
  required List<int> dbBytes,
  required Map<String, String> prefs,
}) {
  final envelope = jsonEncode({
    'version': 1,
    'db': base64Encode(dbBytes),
    'prefs': prefs,
  });
  return utf8.encode(envelope);
}

/// The result of decrypting a backup payload: either a legacy (pre-envelope)
/// raw db file, or a decoded envelope's db bytes plus prefs map.
class DecodedBackup {
  const DecodedBackup({required this.dbBytes, this.prefs});

  final Uint8List dbBytes;
  final Map<String, dynamic>? prefs;
}

/// Parses decrypted backup bytes as either a format-version-1 envelope or a
/// legacy (pre-envelope) raw sqlite file, told apart by sqlite's own file
/// header — see [_sqliteMagic]. Pure/no I/O.
DecodedBackup decodeBackupEnvelope(List<int> decrypted) {
  final isLegacyRawDb =
      decrypted.length >= _sqliteMagic.length &&
      _startsWith(decrypted, _sqliteMagic);

  if (isLegacyRawDb) {
    return DecodedBackup(dbBytes: Uint8List.fromList(decrypted));
  }

  final envelope = jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>;
  return DecodedBackup(
    dbBytes: base64Decode(envelope['db'] as String),
    prefs: envelope['prefs'] as Map<String, dynamic>?,
  );
}

bool _startsWith(List<int> data, List<int> prefix) {
  for (var i = 0; i < prefix.length; i++) {
    if (data[i] != prefix[i]) return false;
  }
  return true;
}

/// Encrypts [plaintext] under a key derived from [passphrase] (PBKDF2,
/// random salt) with AES-256-GCM, and packs `salt | nonce | mac |
/// ciphertext` — everything the decrypting side needs, nothing more.
Future<Uint8List> encryptBackupPayload(
  List<int> plaintext, {
  required String passphrase,
}) async {
  final salt = SecretKeyData.random(length: _saltLength).bytes;
  final key = await _deriveKey(passphrase, salt);
  final nonce = AesGcm.with256bits().newNonce();
  final secretBox = await AesGcm.with256bits().encrypt(
    plaintext,
    secretKey: key,
    nonce: nonce,
  );

  final payload = BytesBuilder()
    ..add(salt)
    ..add(secretBox.nonce)
    ..add(secretBox.mac.bytes)
    ..add(secretBox.cipherText);
  return payload.toBytes();
}

/// Reverses [encryptBackupPayload]. Throws [FormatException] if [payload] is
/// too short to contain a valid salt/nonce/mac, or a decryption exception if
/// [passphrase] is wrong for this payload.
Future<Uint8List> decryptBackupPayload(
  Uint8List payload, {
  required String passphrase,
}) async {
  if (payload.length < _saltLength + _nonceLength + _macLength) {
    throw const FormatException('Backup payload is corrupt or truncated.');
  }
  final salt = payload.sublist(0, _saltLength);
  final nonce = payload.sublist(_saltLength, _saltLength + _nonceLength);
  final mac = payload.sublist(
    _saltLength + _nonceLength,
    _saltLength + _nonceLength + _macLength,
  );
  final cipherText = payload.sublist(_saltLength + _nonceLength + _macLength);

  final key = await _deriveKey(passphrase, salt);
  final decrypted = await AesGcm.with256bits().decrypt(
    SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
    secretKey: key,
  );
  return Uint8List.fromList(decrypted);
}

/// Optional, opt-in, zero-knowledge backup of the local database to
/// Firebase Storage: the passphrase never leaves the device, is used both
/// to derive the AES-256-GCM key and (hashed, one-way) to derive the
/// storage path, so nothing readable — and nothing that identifies which
/// backup belongs to which user — ever reaches the server. Restoring on a
/// new device/reinstall means re-entering the exact same passphrase; there
/// is deliberately no recovery path around that, since the whole point is
/// that we cannot read the backup either.
class CloudBackupService {
  final StorageService _storageService;

  CloudBackupService({StorageService? storageService})
    : _storageService = storageService ?? StorageService();

  /// SharedPreferences keys that live outside the sqflite database but are
  /// still user state worth keeping across a device change — everything
  /// else in SharedPreferences is either a native->Dart drain queue or
  /// derived/re-fetchable, so it's fine to lose (see the CLAUDE.md
  /// native->Dart queue pattern, which never stores durable user state in
  /// SharedPreferences in the first place). Badge unlock state
  /// (AchievementService, BreathBadgeService) was the original bug report;
  /// pack price and language were found in the same sweep and are cheap
  /// enough to include that leaving them out isn't worth the surprise.
  static const List<String> backedUpPrefsKeys = [
    'achievements_state_v1',
    'breath_badges_state_v1',
    'pack_price_try',
    'selected_language_code',
  ];

  @visibleForTesting
  Future<Map<String, String>> readBackedUpPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, String>{};
    for (final key in backedUpPrefsKeys) {
      final value = prefs.get(key);
      if (value == null) continue;
      // Stored as strings regardless of underlying type (String/double/…)
      // so the envelope has one simple shape; _writeBackedUpPrefs parses
      // each key back to its real SharedPreferences type on restore.
      result[key] = value.toString();
    }
    return result;
  }

  @visibleForTesting
  Future<void> writeBackedUpPrefs(Map<String, dynamic> prefsJson) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in prefsJson.entries) {
      if (!backedUpPrefsKeys.contains(entry.key)) continue;
      final raw = entry.value as String;
      switch (entry.key) {
        case 'pack_price_try':
          final parsed = double.tryParse(raw);
          if (parsed != null) await prefs.setDouble(entry.key, parsed);
          break;
        default:
          await prefs.setString(entry.key, raw);
      }
    }
  }

  /// Encrypts the whole local database file plus [backedUpPrefsKeys] and
  /// uploads them as one envelope. Throws if there's no local data yet
  /// (nothing to back up) or the upload fails — callers should surface
  /// that as a plain error message, not retry silently (a failed backup
  /// must be visibly failed, not silently lost).
  Future<void> backup({required String passphrase}) async {
    final dbPath = await _storageService.databaseFilePath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw StateError('No local data to back up yet.');
    }

    // A read-only copy of a live sqflite file can be safely read directly
    // (WAL-mode sqflite still keeps the main file consistent for readers);
    // no need to close the live connection just to back up.
    final rawDbBytes = await dbFile.readAsBytes();
    final prefsJson = await readBackedUpPrefs();
    final envelope = encodeBackupEnvelope(dbBytes: rawDbBytes, prefs: prefsJson);
    final payload = await encryptBackupPayload(envelope, passphrase: passphrase);

    final path = await storagePathFor(passphrase);
    await FirebaseStorage.instance.ref(path).putData(
      payload,
      SettableMetadata(contentType: 'application/octet-stream'),
    );
  }

  /// Downloads and decrypts the backup for [passphrase], then restores the
  /// local database file (and, for envelope-format backups, the badge/
  /// price/language SharedPreferences keys) from it. Returns false (no
  /// exception) when no backup exists for that passphrase, so callers can
  /// show "not found" rather than a generic error. A wrong passphrase for
  /// an *existing* backup instead fails decryption below and throws.
  Future<bool> restore({required String passphrase}) async {
    final path = await storagePathFor(passphrase);
    final Uint8List? payload;
    try {
      payload = await FirebaseStorage.instance.ref(path).getData(
        50 * 1024 * 1024,
      );
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return false;
      }
      rethrow;
    }
    if (payload == null) {
      return false;
    }

    final decrypted = await decryptBackupPayload(payload, passphrase: passphrase);
    final decoded = decodeBackupEnvelope(decrypted);

    await _storageService.closeDatabaseConnection();
    final dbPath = await _storageService.databaseFilePath();
    await File(dbPath).writeAsBytes(decoded.dbBytes, flush: true);

    if (decoded.prefs != null) {
      await writeBackedUpPrefs(decoded.prefs!);
    }

    return true;
  }
}
