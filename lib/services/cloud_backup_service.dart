import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'storage_service.dart';

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

  Future<String> _storagePathFor(String passphrase) async {
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
    return pbkdf2.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
  }

  /// Encrypts the whole local database file and uploads it. Throws if
  /// there's no local data yet (nothing to back up) or the upload fails —
  /// callers should surface that as a plain error message, not retry
  /// silently (a failed backup must be visibly failed, not silently lost).
  Future<void> backup({required String passphrase}) async {
    final dbPath = await _storageService.databaseFilePath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw StateError('No local data to back up yet.');
    }

    // A read-only copy of a live sqflite file can be safely read directly
    // (WAL-mode sqflite still keeps the main file consistent for readers);
    // no need to close the live connection just to back up.
    final rawBytes = await dbFile.readAsBytes();

    final salt = SecretKeyData.random(length: 16).bytes;
    final key = await _deriveKey(passphrase, salt);
    final nonce = AesGcm.with256bits().newNonce();
    final secretBox = await AesGcm.with256bits().encrypt(
      rawBytes,
      secretKey: key,
      nonce: nonce,
    );

    // salt | nonce | mac | ciphertext — everything the decrypting side
    // needs, nothing more.
    final payload = BytesBuilder()
      ..add(salt)
      ..add(secretBox.nonce)
      ..add(secretBox.mac.bytes)
      ..add(secretBox.cipherText);

    final path = await _storagePathFor(passphrase);
    await FirebaseStorage.instance.ref(path).putData(
      payload.toBytes(),
      SettableMetadata(contentType: 'application/octet-stream'),
    );
  }

  /// Downloads and decrypts the backup for [passphrase], then overwrites
  /// the local database file with it. Returns false (no exception) when no
  /// backup exists for that passphrase, so callers can show "not found"
  /// rather than a generic error. A wrong passphrase for an *existing*
  /// backup instead fails decryption below and throws.
  Future<bool> restore({required String passphrase}) async {
    final path = await _storagePathFor(passphrase);
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

    const saltLength = 16;
    const nonceLength = 12;
    const macLength = 16;
    if (payload.length < saltLength + nonceLength + macLength) {
      throw const FormatException('Backup payload is corrupt or truncated.');
    }
    final salt = payload.sublist(0, saltLength);
    final nonce = payload.sublist(saltLength, saltLength + nonceLength);
    final mac = payload.sublist(
      saltLength + nonceLength,
      saltLength + nonceLength + macLength,
    );
    final cipherText = payload.sublist(saltLength + nonceLength + macLength);

    final key = await _deriveKey(passphrase, salt);
    final decrypted = await AesGcm.with256bits().decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
      secretKey: key,
    );

    await _storageService.closeDatabaseConnection();
    final dbPath = await _storageService.databaseFilePath();
    await File(dbPath).writeAsBytes(decrypted, flush: true);
    return true;
  }
}
