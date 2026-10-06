// lib/features/sync/vault_crypto.dart
// Stage C: sync vault encryption protocol v1 (spec §10): header slots + revision objects.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Protocol version understood by this build (v1 legacy).
const int kVaultProtocolVersion = 1;

/// Protocol version 2 (multi-key append-only protocol).
const int kVaultProtocolVersionV2 = 2;

/// Maximum size of a single remote object (header or revision).
const int kMaxObjectBytes = 16 * 1024 * 1024;

const String _headerFormat = 'suicun-vault-header';
const String _keyFormat = 'suicun-vault-key';
const String _revisionFormat = 'suicun-revision';
const Set<String> _entityTypes = {'record', 'category', 'tag'};

// Caps for untrusted KDF parameters (same as backup_crypto.dart).
const int _maxMemoryKb = 1 << 18; // 256 MiB
const int _maxIterations = 16;
const int _maxParallelism = 16;

enum VaultCryptoCode {
  unsupportedVersion,
  unsupportedKdf,
  kdfParamsTooLarge,
  malformed,
  wrongPasswordOrKey,
  tampered,
  payloadTooLarge,
}

class VaultCryptoError implements Exception {
  const VaultCryptoError(this.code, [this.detail = '']);

  final VaultCryptoCode code;

  /// Safe diagnostic only; never keys, passwords or plaintext.
  final String detail;

  @override
  String toString() =>
      'VaultCryptoError(${code.name}${detail.isEmpty ? '' : ': $detail'})';
}

/// Argon2id parameters (RFC 9106 first recommendation, p=1 for weak phones).
class VaultKdfParams {
  const VaultKdfParams({
    this.memoryKb = 65536,
    this.iterations = 3,
    this.parallelism = 1,
  });

  final int memoryKb;
  final int iterations;
  final int parallelism;

  Map<String, Object?> toJson(String saltB64) => {
        'algorithm': 'argon2id',
        'version': 19,
        'memory_kb': memoryKb,
        'iterations': iterations,
        'parallelism': parallelism,
        'salt_b64': saltB64,
      };

  /// Parses untrusted parameters, enforcing upper bounds.
  static VaultKdfParams fromJson(Map<String, Object?> json) {
    if (json['algorithm'] != 'argon2id' || json['version'] != 19) {
      throw const VaultCryptoError(VaultCryptoCode.unsupportedKdf);
    }
    int asInt(Object? v, String name, int max) {
      if (v is! int || v <= 0) {
        throw VaultCryptoError(VaultCryptoCode.malformed, 'kdf.$name');
      }
      if (v > max) {
        throw VaultCryptoError(VaultCryptoCode.kdfParamsTooLarge, name);
      }
      return v;
    }

    return VaultKdfParams(
      memoryKb: asInt(json['memory_kb'], 'memory_kb', _maxMemoryKb),
      iterations: asInt(json['iterations'], 'iterations', _maxIterations),
      parallelism: asInt(json['parallelism'], 'parallelism', _maxParallelism),
    );
  }
}

class VaultSlot {
  const VaultSlot({
    required this.type,
    required this.nonce,
    required this.wrapped,
    this.keyId,
  });

  /// `password` or `recovery`.
  final String type;
  final Uint8List nonce;
  final Uint8List wrapped;
  final String? keyId;

  Map<String, Object?> toJson() => {
        'type': type,
        if (keyId != null) 'key_id': keyId,
        'nonce_b64': base64Encode(nonce),
        'wrapped_b64': base64Encode(wrapped),
      };
}

class VaultHeader {
  const VaultHeader({
    required this.protocolVersion,
    required this.vaultId,
    required this.kdf,
    required this.salt,
    required this.slots,
  });

  final int protocolVersion;
  final String vaultId;
  final VaultKdfParams kdf;
  final Uint8List salt;
  final List<VaultSlot> slots;

  VaultSlot? slotOfType(String type) {
    for (final s in slots) {
      if (s.type == type) return s;
    }
    return null;
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert({
        'format': _headerFormat,
        'protocol_version': protocolVersion,
        'vault_id': vaultId,
        'kdf': kdf.toJson(base64Encode(salt)),
        'slots': [for (final s in slots) s.toJson()],
      });

  /// Parses and validates an untrusted header. Never decrypts anything.
  static VaultHeader parse(String headerJson) {
    if (headerJson.length > kMaxObjectBytes) {
      throw const VaultCryptoError(VaultCryptoCode.payloadTooLarge);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(headerJson);
    } catch (_) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'header json');
    }
    if (decoded is! Map<String, Object?>) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'header shape');
    }
    if (decoded['format'] != _headerFormat) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'header format');
    }
    final version = decoded['protocol_version'];
    if (version is! int) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'version');
    }
    if (version != kVaultProtocolVersion) {
      throw VaultCryptoError(
          VaultCryptoCode.unsupportedVersion, 'protocol_version=$version');
    }
    final vaultId = decoded['vault_id'];
    if (vaultId is! String || vaultId.isEmpty) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'vault_id');
    }
    final kdfJson = decoded['kdf'];
    if (kdfJson is! Map<String, Object?>) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'kdf');
    }
    final kdf = VaultKdfParams.fromJson(kdfJson);
    final salt = _b64(kdfJson['salt_b64'], 'salt');
    if (salt.length != 16) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'salt length');
    }
    final slotsJson = decoded['slots'];
    if (slotsJson is! List || slotsJson.isEmpty || slotsJson.length > 8) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'slots');
    }
    final slots = <VaultSlot>[];
    for (final s in slotsJson) {
      if (s is! Map<String, Object?>) {
        throw const VaultCryptoError(VaultCryptoCode.malformed, 'slot shape');
      }
      final type = s['type'];
      if (type is! String || type.isEmpty) {
        throw const VaultCryptoError(VaultCryptoCode.malformed, 'slot type');
      }
      final nonce = _b64(s['nonce_b64'], 'slot nonce');
      final wrapped = _b64(s['wrapped_b64'], 'slot wrapped');
      if (nonce.length != 12 || wrapped.length != 48) {
        throw const VaultCryptoError(
            VaultCryptoCode.malformed, 'slot field length');
      }
      final keyId = s['key_id'];
      if (keyId != null && keyId is! String) {
        throw const VaultCryptoError(VaultCryptoCode.malformed, 'key_id');
      }
      slots.add(VaultSlot(
        type: type,
        nonce: nonce,
        wrapped: wrapped,
        keyId: keyId as String?,
      ));
    }
    return VaultHeader(
      protocolVersion: version,
      vaultId: vaultId,
      kdf: kdf,
      salt: salt,
      slots: slots,
    );
  }
}

class VaultKeyObject {
  const VaultKeyObject({
    required this.protocolVersion,
    required this.keyId,
    required this.variant,
    required this.origin,
    required this.createdByDevice,
    required this.createdAt,
    required this.kdf,
    required this.salt,
    required this.slots,
    this.legacyVaultId,
  });

  final int protocolVersion;
  final String keyId;
  final String variant;
  final String origin;
  final String createdByDevice;
  final String createdAt;
  final VaultKdfParams kdf;
  final Uint8List salt;
  final List<VaultSlot> slots;
  final String? legacyVaultId;

  VaultSlot? slotOfType(String type) {
    for (final s in slots) {
      if (s.type == type) return s;
    }
    return null;
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert({
        'format': _keyFormat,
        'protocol_version': protocolVersion,
        'key_id': keyId,
        'variant': variant,
        'origin': origin,
        'created_by_device': createdByDevice,
        'created_at': createdAt,
        if (legacyVaultId != null) 'legacy_vault_id': legacyVaultId,
        'kdf': kdf.toJson(base64Encode(salt)),
        'slots': [for (final s in slots) s.toJson()],
      });

  static final _hexRegex = RegExp(r'^[0-9a-f]+$');

  static VaultKeyObject parse(String jsonString) {
    if (jsonString.length > kMaxObjectBytes) {
      throw const VaultCryptoError(VaultCryptoCode.payloadTooLarge);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (_) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'key json');
    }
    if (decoded is! Map<String, Object?>) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'key shape');
    }
    if (decoded['format'] != _keyFormat) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'key format');
    }
    final version = decoded['protocol_version'];
    if (version is! int) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'version');
    }
    if (version > kVaultProtocolVersionV2) {
      throw VaultCryptoError(
          VaultCryptoCode.unsupportedVersion, 'protocol_version=$version');
    }
    if (version != kVaultProtocolVersionV2) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'protocol_version');
    }
    final keyId = decoded['key_id'];
    if (keyId is! String ||
        keyId.length != 16 ||
        !_hexRegex.hasMatch(keyId)) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'key_id');
    }
    final variant = decoded['variant'];
    if (variant is! String ||
        variant.length != 8 ||
        !_hexRegex.hasMatch(variant)) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'variant');
    }
    final origin = decoded['origin'];
    if (origin is! String || (origin != 'created' && origin != 'v1-migrated')) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'origin');
    }
    final createdByDevice = decoded['created_by_device'];
    if (createdByDevice is! String || createdByDevice.isEmpty) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'created_by_device');
    }
    final createdAt = decoded['created_at'];
    if (createdAt is! String || createdAt.isEmpty) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'created_at');
    }
    final legacyVaultId = decoded['legacy_vault_id'];
    if (legacyVaultId != null && (legacyVaultId is! String || legacyVaultId.isEmpty)) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'legacy_vault_id');
    }
    final kdfJson = decoded['kdf'];
    if (kdfJson is! Map<String, Object?>) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'kdf');
    }
    final kdf = VaultKdfParams.fromJson(kdfJson);
    final salt = _b64(kdfJson['salt_b64'], 'salt');
    if (salt.length != 16) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'salt length');
    }
    final slotsJson = decoded['slots'];
    if (slotsJson is! List || slotsJson.isEmpty || slotsJson.length > 8) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'slots');
    }
    final slots = <VaultSlot>[];
    for (final s in slotsJson) {
      if (s is! Map<String, Object?>) {
        throw const VaultCryptoError(VaultCryptoCode.malformed, 'slot shape');
      }
      final type = s['type'];
      if (type is! String || type.isEmpty) {
        throw const VaultCryptoError(VaultCryptoCode.malformed, 'slot type');
      }
      final nonce = _b64(s['nonce_b64'], 'slot nonce');
      final wrapped = _b64(s['wrapped_b64'], 'slot wrapped');
      if (nonce.length != 12 || wrapped.length != 48) {
        throw const VaultCryptoError(
            VaultCryptoCode.malformed, 'slot field length');
      }
      final slotKeyId = s['key_id'];
      if (slotKeyId != null && slotKeyId is! String) {
        throw const VaultCryptoError(VaultCryptoCode.malformed, 'key_id');
      }
      slots.add(VaultSlot(
        type: type,
        nonce: nonce,
        wrapped: wrapped,
        keyId: slotKeyId as String?,
      ));
    }
    return VaultKeyObject(
      protocolVersion: version,
      keyId: keyId,
      variant: variant,
      origin: origin,
      createdByDevice: createdByDevice,
      createdAt: createdAt,
      kdf: kdf,
      salt: salt,
      slots: slots,
      legacyVaultId: legacyVaultId as String?,
    );
  }
}

class CreatedKeyObject {
  const CreatedKeyObject({
    required this.keyJson,
    required this.keyId,
    required this.variant,
    required this.kvault,
    required this.recoveryKey,
  });

  final String keyJson;
  final String keyId;
  final String variant;
  final Uint8List kvault;
  final String recoveryKey;
}

class UnlockedKey {
  const UnlockedKey({
    required this.keyId,
    required this.kvault,
    this.legacyVaultId,
  });

  final String keyId;
  final Uint8List kvault;
  final String? legacyVaultId;
}

class MultiKeySession {
  MultiKeySession({
    Map<String, Uint8List>? keys,
    Map<String, Uint8List>? legacyKeys,
    String? activeKeyId,
  })  : keys = keys ?? <String, Uint8List>{},
        legacyKeys = legacyKeys ?? <String, Uint8List>{},
        activeKeyId = activeKeyId ?? pickActiveKeyId((keys ?? const {}).keys);

  final Map<String, Uint8List> keys;
  final Map<String, Uint8List> legacyKeys;
  String activeKeyId;

  static String pickActiveKeyId(Iterable<String> ids) {
    if (ids.isEmpty) return '';
    final sorted = ids.toList()..sort();
    return sorted.first;
  }
}

/// In-memory unlocked vault. [kvault] must never be persisted or logged.
class VaultSession {
  const VaultSession({required this.vaultId, required this.kvault});

  final String vaultId;
  final Uint8List kvault;
}

class CreatedVault {
  const CreatedVault({
    required this.headerJson,
    required this.session,
    required this.recoveryKey,
  });

  final String headerJson;
  final VaultSession session;

  /// Recovery key in display format (16 groups of 4 hex chars).
  final String recoveryKey;
}

class RevisionEnvelope {
  const RevisionEnvelope({
    required this.protocolVersion,
    this.vaultId,
    this.keyId,
    required this.revisionId,
    required this.entityType,
    required this.entityId,
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final int protocolVersion;
  final String? vaultId;
  final String? keyId;
  final String revisionId;
  final String entityType;
  final String entityId;
  final Uint8List nonce;
  final Uint8List cipherText;
  final Uint8List mac;
}

Uint8List _b64(Object? v, String name) {
  if (v is! String) {
    throw VaultCryptoError(VaultCryptoCode.malformed, name);
  }
  try {
    return base64Decode(v);
  } catch (_) {
    throw VaultCryptoError(VaultCryptoCode.malformed, '$name base64');
  }
}

class VaultCrypto {
  VaultCrypto({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  static final _aesGcm = AesGcm.with256bits();
  static final _sha256 = Sha256();

  Uint8List _randomBytes(int length) {
    final b = Uint8List(length);
    for (var i = 0; i < length; i++) {
      b[i] = _random.nextInt(256);
    }
    return b;
  }

  String _uuidV4() {
    final b = _randomBytes(16);
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = _hex(b);
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _aad(String s) => utf8.encode(s);

  Future<SecretKey> _deriveKey(
      String password, Uint8List salt, VaultKdfParams p) {
    final argon2 = Argon2id(
      parallelism: p.parallelism,
      memory: p.memoryKb,
      iterations: p.iterations,
      hashLength: 32,
    );
    return argon2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  Future<SecretKey> _recoveryWrapKey(Uint8List raw) async {
    final hash = await _sha256.hash([
      ...utf8.encode('suicun/v1/recovery-wrap/'),
      ...raw,
    ]);
    return SecretKey(hash.bytes);
  }

  Future<VaultSlot> _wrap({
    required String type,
    required SecretKey wrapKey,
    required Uint8List kvault,
    required String vaultId,
    String? keyId,
  }) async {
    final nonce = _randomBytes(12);
    final box = await _aesGcm.encrypt(
      kvault,
      secretKey: wrapKey,
      nonce: nonce,
      aad: _aad('suicun/v1/header/$vaultId/$type'),
    );
    return VaultSlot(
      type: type,
      nonce: nonce,
      wrapped: Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
      keyId: keyId,
    );
  }

  Future<VaultSession> _unwrap({
    required VaultHeader header,
    required VaultSlot slot,
    required SecretKey wrapKey,
  }) async {
    try {
      final box = SecretBox(
        slot.wrapped.sublist(0, 32),
        nonce: slot.nonce,
        mac: Mac(slot.wrapped.sublist(32)),
      );
      final clear = await _aesGcm.decrypt(
        box,
        secretKey: wrapKey,
        aad: _aad('suicun/v1/header/${header.vaultId}/${slot.type}'),
      );
      return VaultSession(
        vaultId: header.vaultId,
        kvault: Uint8List.fromList(clear),
      );
    } on SecretBoxAuthenticationError {
      throw const VaultCryptoError(VaultCryptoCode.wrongPasswordOrKey);
    }
  }

  Future<CreatedVault> createVault({
    required String password,
    VaultKdfParams kdf = const VaultKdfParams(),
  }) async {
    if (password.isEmpty) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'empty password');
    }
    final vaultId = _uuidV4();
    final kvault = _randomBytes(32);
    final salt = _randomBytes(16);
    final recoveryRaw = _randomBytes(32);

    final wrapKey = await _deriveKey(password, salt, kdf);
    final passwordSlot = await _wrap(
      type: 'password',
      wrapKey: wrapKey,
      kvault: kvault,
      vaultId: vaultId,
    );
    final keyIdHash = await _sha256.hash(recoveryRaw);
    final recoverySlot = await _wrap(
      type: 'recovery',
      wrapKey: await _recoveryWrapKey(recoveryRaw),
      kvault: kvault,
      vaultId: vaultId,
      keyId: _hex(keyIdHash.bytes).substring(0, 8),
    );
    final header = VaultHeader(
      protocolVersion: kVaultProtocolVersion,
      vaultId: vaultId,
      kdf: kdf,
      salt: salt,
      slots: [passwordSlot, recoverySlot],
    );
    return CreatedVault(
      headerJson: header.toJsonString(),
      session: VaultSession(vaultId: vaultId, kvault: kvault),
      recoveryKey: formatRecoveryKey(recoveryRaw),
    );
  }

  Future<VaultSession> openWithPassword(
      String headerJson, String password) async {
    final header = VaultHeader.parse(headerJson);
    final slot = header.slotOfType('password');
    if (slot == null) {
      throw const VaultCryptoError(
          VaultCryptoCode.malformed, 'no password slot');
    }
    final key = await _deriveKey(password, header.salt, header.kdf);
    return _unwrap(header: header, slot: slot, wrapKey: key);
  }

  Future<VaultSession> openWithRecoveryKey(
      String headerJson, String recoveryKey) async {
    final header = VaultHeader.parse(headerJson);
    final slot = header.slotOfType('recovery');
    if (slot == null) {
      throw const VaultCryptoError(
          VaultCryptoCode.malformed, 'no recovery slot');
    }
    final raw = parseRecoveryKey(recoveryKey);
    final keyId = _hex((await _sha256.hash(raw)).bytes).substring(0, 8);
    if (slot.keyId != null && slot.keyId != keyId) {
      throw const VaultCryptoError(VaultCryptoCode.wrongPasswordOrKey);
    }
    return _unwrap(
      header: header,
      slot: slot,
      wrapKey: await _recoveryWrapKey(raw),
    );
  }

  /// Encrypts a full revision [payload] and returns the object file bytes.
  Future<Uint8List> encryptRevision({
    required VaultSession session,
    required String revisionId,
    required String entityType,
    required String entityId,
    required Map<String, Object?> payload,
  }) async {
    if (!_entityTypes.contains(entityType) ||
        revisionId.isEmpty ||
        entityId.isEmpty) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'envelope ids');
    }
    if (payload['revision_id'] != revisionId ||
        payload['entity_type'] != entityType ||
        payload['entity_id'] != entityId) {
      throw const VaultCryptoError(
          VaultCryptoCode.malformed, 'payload ids do not match envelope');
    }
    final nonce = _randomBytes(12);
    final box = await _aesGcm.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: SecretKey(session.kvault),
      nonce: nonce,
      aad: _aad('suicun/v1/object/${session.vaultId}/$revisionId/$entityType'),
    );
    final bytes = utf8.encode(jsonEncode({
      'format': _revisionFormat,
      'protocol_version': kVaultProtocolVersion,
      'vault_id': session.vaultId,
      'revision_id': revisionId,
      'entity_type': entityType,
      'entity_id': entityId,
      'nonce_b64': base64Encode(nonce),
      'ciphertext_b64': base64Encode([...box.cipherText, ...box.mac.bytes]),
    }));
    if (bytes.length > kMaxObjectBytes) {
      throw const VaultCryptoError(VaultCryptoCode.payloadTooLarge);
    }
    return Uint8List.fromList(bytes);
  }

  /// Validates the outer envelope without any key.
  /// Accepts protocol_version 1 (vault_id present, key_id null) and 2 (key_id 16 hex).
  /// Version > 2 throws unsupportedVersion.
  RevisionEnvelope parseEnvelope(Uint8List objectBytes) {
    if (objectBytes.length > kMaxObjectBytes) {
      throw const VaultCryptoError(VaultCryptoCode.payloadTooLarge);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(objectBytes));
    } catch (_) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'object json');
    }
    if (decoded is! Map<String, Object?>) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'object shape');
    }
    final json = decoded;
    if (json['format'] != _revisionFormat) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'object format');
    }
    final version = decoded['protocol_version'];
    if (version is! int) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'version');
    }
    if (version > kVaultProtocolVersionV2) {
      throw VaultCryptoError(
          VaultCryptoCode.unsupportedVersion, 'protocol_version=$version');
    }
    if (version != kVaultProtocolVersion && version != kVaultProtocolVersionV2) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'protocol_version');
    }
    String str(String name) {
      final v = json[name];
      if (v is! String || v.isEmpty) {
        throw VaultCryptoError(VaultCryptoCode.malformed, name);
      }
      return v;
    }

    final entityType = str('entity_type');
    if (!_entityTypes.contains(entityType)) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'entity_type');
    }
    final nonce = _b64(decoded['nonce_b64'], 'nonce');
    if (nonce.length != 12) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'nonce length');
    }
    final ctMac = _b64(decoded['ciphertext_b64'], 'ciphertext');
    if (ctMac.length <= 16) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'ciphertext');
    }

    String? vaultId;
    String? keyId;
    if (version == kVaultProtocolVersion) {
      vaultId = str('vault_id');
    } else {
      final k = json['key_id'];
      if (k is! String || k.length != 16 || !VaultKeyObject._hexRegex.hasMatch(k)) {
        throw const VaultCryptoError(VaultCryptoCode.malformed, 'key_id');
      }
      keyId = k;
    }

    return RevisionEnvelope(
      protocolVersion: version,
      vaultId: vaultId,
      keyId: keyId,
      revisionId: str('revision_id'),
      entityType: entityType,
      entityId: str('entity_id'),
      nonce: nonce,
      cipherText: Uint8List.sublistView(ctMac, 0, ctMac.length - 16),
      mac: Uint8List.sublistView(ctMac, ctMac.length - 16),
    );
  }

  /// Decrypts an object and returns its validated payload map (v1).
  Future<Map<String, Object?>> decryptRevision({
    required VaultSession session,
    required Uint8List objectBytes,
  }) async {
    final env = parseEnvelope(objectBytes);
    if (env.vaultId != session.vaultId) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'vault mismatch');
    }
    final List<int> clear;
    try {
      clear = await _aesGcm.decrypt(
        SecretBox(env.cipherText, nonce: env.nonce, mac: Mac(env.mac)),
        secretKey: SecretKey(session.kvault),
        aad: _aad('suicun/v1/object/${env.vaultId}/${env.revisionId}/'
            '${env.entityType}'),
      );
    } on SecretBoxAuthenticationError {
      throw const VaultCryptoError(VaultCryptoCode.tampered);
    }
    final Object? payload;
    try {
      payload = jsonDecode(utf8.decode(clear));
    } catch (_) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'payload json');
    }
    if (payload is! Map<String, Object?>) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'payload shape');
    }
    if (payload['revision_id'] != env.revisionId ||
        payload['entity_type'] != env.entityType ||
        payload['entity_id'] != env.entityId) {
      throw const VaultCryptoError(
          VaultCryptoCode.malformed, 'payload ids do not match envelope');
    }
    return payload;
  }

  // ── v2 Methods ──────────────────────────────────────────────────────────────

  Future<CreatedKeyObject> createKeyObject({
    required String password,
    VaultKdfParams kdf = const VaultKdfParams(),
    String? origin,
    String? createdByDevice,
  }) async {
    if (password.isEmpty) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'empty password');
    }
    final kvault = _randomBytes(32);
    final keyIdBytes = _randomBytes(8);
    final keyId = _hex(keyIdBytes);
    final variantBytes = _randomBytes(4);
    final variant = _hex(variantBytes);
    final salt = _randomBytes(16);
    final recoveryRaw = _randomBytes(32);

    final wrapKey = await _deriveKey(password, salt, kdf);
    final passNonce = _randomBytes(12);
    final passBox = await _aesGcm.encrypt(
      kvault,
      secretKey: wrapKey,
      nonce: passNonce,
      aad: _aad('suicun/v2/keyslot/$keyId/password'),
    );
    final passwordSlot = VaultSlot(
      type: 'password',
      nonce: passNonce,
      wrapped: Uint8List.fromList([...passBox.cipherText, ...passBox.mac.bytes]),
    );

    final recWrapKey = await _recoveryWrapKey(recoveryRaw);
    final recNonce = _randomBytes(12);
    final recBox = await _aesGcm.encrypt(
      kvault,
      secretKey: recWrapKey,
      nonce: recNonce,
      aad: _aad('suicun/v2/keyslot/$keyId/recovery'),
    );
    final keyIdHash = await _sha256.hash(recoveryRaw);
    final recoverySlot = VaultSlot(
      type: 'recovery',
      nonce: recNonce,
      wrapped: Uint8List.fromList([...recBox.cipherText, ...recBox.mac.bytes]),
      keyId: _hex(keyIdHash.bytes).substring(0, 8),
    );

    final keyObj = VaultKeyObject(
      protocolVersion: kVaultProtocolVersionV2,
      keyId: keyId,
      variant: variant,
      origin: origin ?? 'created',
      createdByDevice: createdByDevice ?? 'device-${_hex(_randomBytes(4))}',
      createdAt: DateTime.now().toUtc().toIso8601String(),
      kdf: kdf,
      salt: salt,
      slots: [passwordSlot, recoverySlot],
    );

    return CreatedKeyObject(
      keyJson: keyObj.toJsonString(),
      keyId: keyId,
      variant: variant,
      kvault: kvault,
      recoveryKey: formatRecoveryKey(recoveryRaw),
    );
  }

  Future<UnlockedKey> openKeyObjectWithPassword(
    String keyJson,
    String password,
  ) async {
    final keyObj = VaultKeyObject.parse(keyJson);
    final slot = keyObj.slotOfType('password');
    if (slot == null) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'no password slot');
    }
    final wrapKey = await _deriveKey(password, keyObj.salt, keyObj.kdf);
    try {
      final box = SecretBox(
        slot.wrapped.sublist(0, 32),
        nonce: slot.nonce,
        mac: Mac(slot.wrapped.sublist(32)),
      );
      final clear = await _aesGcm.decrypt(
        box,
        secretKey: wrapKey,
        aad: _aad('suicun/v2/keyslot/${keyObj.keyId}/${slot.type}'),
      );
      return UnlockedKey(
        keyId: keyObj.keyId,
        kvault: Uint8List.fromList(clear),
        legacyVaultId: keyObj.legacyVaultId,
      );
    } on SecretBoxAuthenticationError {
      throw const VaultCryptoError(VaultCryptoCode.wrongPasswordOrKey);
    }
  }

  Future<UnlockedKey> openKeyObjectWithRecoveryKey(
    String keyJson,
    String recoveryKey,
  ) async {
    final keyObj = VaultKeyObject.parse(keyJson);
    final slot = keyObj.slotOfType('recovery');
    if (slot == null) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'no recovery slot');
    }
    final raw = parseRecoveryKey(recoveryKey);
    final keyIdShort = _hex((await _sha256.hash(raw)).bytes).substring(0, 8);
    if (slot.keyId != null && slot.keyId != keyIdShort) {
      throw const VaultCryptoError(VaultCryptoCode.wrongPasswordOrKey);
    }
    final wrapKey = await _recoveryWrapKey(raw);
    final box = SecretBox(
      slot.wrapped.sublist(0, 32),
      nonce: slot.nonce,
      mac: Mac(slot.wrapped.sublist(32)),
    );

    try {
      final clear = await _aesGcm.decrypt(
        box,
        secretKey: wrapKey,
        aad: _aad('suicun/v2/keyslot/${keyObj.keyId}/${slot.type}'),
      );
      return UnlockedKey(
        keyId: keyObj.keyId,
        kvault: Uint8List.fromList(clear),
        legacyVaultId: keyObj.legacyVaultId,
      );
    } on SecretBoxAuthenticationError {
      // For recovery on a v1-migrated key object: if v2-AAD unwrap fails and
      // legacyVaultId is present, retry once with the v1 slot AAD
      // suicun/v1/header/<legacy_vault_id>/recovery (migration copies the recovery
      // wrapped bytes verbatim).
      if (keyObj.legacyVaultId != null) {
        try {
          final clear = await _aesGcm.decrypt(
            box,
            secretKey: wrapKey,
            aad: _aad('suicun/v1/header/${keyObj.legacyVaultId}/${slot.type}'),
          );
          return UnlockedKey(
            keyId: keyObj.keyId,
            kvault: Uint8List.fromList(clear),
            legacyVaultId: keyObj.legacyVaultId,
          );
        } on SecretBoxAuthenticationError {
          throw const VaultCryptoError(VaultCryptoCode.wrongPasswordOrKey);
        }
      }
      throw const VaultCryptoError(VaultCryptoCode.wrongPasswordOrKey);
    }
  }

  Future<Uint8List> encryptRevisionV2({
    required Uint8List kvault,
    required String keyId,
    required String revisionId,
    required String entityType,
    required String entityId,
    required Map<String, Object?> payload,
  }) async {
    if (!_entityTypes.contains(entityType) ||
        revisionId.isEmpty ||
        entityId.isEmpty ||
        keyId.length != 16 ||
        !VaultKeyObject._hexRegex.hasMatch(keyId)) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'envelope ids');
    }
    if (payload['revision_id'] != revisionId ||
        payload['entity_type'] != entityType ||
        payload['entity_id'] != entityId) {
      throw const VaultCryptoError(
          VaultCryptoCode.malformed, 'payload ids do not match envelope');
    }
    final nonce = _randomBytes(12);
    final box = await _aesGcm.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: SecretKey(kvault),
      nonce: nonce,
      aad: _aad('suicun/v2/object/$keyId/$revisionId/$entityType'),
    );
    final bytes = utf8.encode(jsonEncode({
      'format': _revisionFormat,
      'protocol_version': kVaultProtocolVersionV2,
      'key_id': keyId,
      'revision_id': revisionId,
      'entity_type': entityType,
      'entity_id': entityId,
      'nonce_b64': base64Encode(nonce),
      'ciphertext_b64': base64Encode([...box.cipherText, ...box.mac.bytes]),
    }));
    if (bytes.length > kMaxObjectBytes) {
      throw const VaultCryptoError(VaultCryptoCode.payloadTooLarge);
    }
    return Uint8List.fromList(bytes);
  }

  Future<Map<String, Object?>> decryptRevisionV2({
    required Uint8List kvault,
    required Uint8List objectBytes,
  }) async {
    final env = parseEnvelope(objectBytes);
    if (env.protocolVersion != kVaultProtocolVersionV2 || env.keyId == null) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'not v2 envelope');
    }
    final List<int> clear;
    try {
      clear = await _aesGcm.decrypt(
        SecretBox(env.cipherText, nonce: env.nonce, mac: Mac(env.mac)),
        secretKey: SecretKey(kvault),
        aad: _aad('suicun/v2/object/${env.keyId}/${env.revisionId}/${env.entityType}'),
      );
    } on SecretBoxAuthenticationError {
      throw const VaultCryptoError(VaultCryptoCode.tampered);
    }
    final Object? payload;
    try {
      payload = jsonDecode(utf8.decode(clear));
    } catch (_) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'payload json');
    }
    if (payload is! Map<String, Object?>) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'payload shape');
    }
    if (payload['revision_id'] != env.revisionId ||
        payload['entity_type'] != env.entityType ||
        payload['entity_id'] != env.entityId) {
      throw const VaultCryptoError(
          VaultCryptoCode.malformed, 'payload ids do not match envelope');
    }
    return payload;
  }

  Future<Map<String, Object?>> decryptLegacyRevision({
    required Uint8List kvault,
    required String legacyVaultId,
    required Uint8List objectBytes,
  }) async {
    final env = parseEnvelope(objectBytes);
    if (env.protocolVersion != kVaultProtocolVersion || env.vaultId != legacyVaultId) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'legacy vault mismatch');
    }
    final List<int> clear;
    try {
      clear = await _aesGcm.decrypt(
        SecretBox(env.cipherText, nonce: env.nonce, mac: Mac(env.mac)),
        secretKey: SecretKey(kvault),
        aad: _aad('suicun/v1/object/$legacyVaultId/${env.revisionId}/${env.entityType}'),
      );
    } on SecretBoxAuthenticationError {
      throw const VaultCryptoError(VaultCryptoCode.tampered);
    }
    final Object? payload;
    try {
      payload = jsonDecode(utf8.decode(clear));
    } catch (_) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'payload json');
    }
    if (payload is! Map<String, Object?>) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'payload shape');
    }
    if (payload['revision_id'] != env.revisionId ||
        payload['entity_type'] != env.entityType ||
        payload['entity_id'] != env.entityId) {
      throw const VaultCryptoError(
          VaultCryptoCode.malformed, 'payload ids do not match envelope');
    }
    return payload;
  }

  /// 64 lowercase hex chars as 16 dash-separated groups of 4.
  static String formatRecoveryKey(Uint8List raw) {
    if (raw.length != 32) {
      throw const VaultCryptoError(VaultCryptoCode.malformed, 'key length');
    }
    final h = _hex(raw);
    return [for (var i = 0; i < 64; i += 4) h.substring(i, i + 4)].join('-');
  }

  static Uint8List parseRecoveryKey(String display) {
    final hex = display.toLowerCase().replaceAll(RegExp(r'[^0-9a-f]'), '');
    if (hex.length != 64) {
      throw const VaultCryptoError(
          VaultCryptoCode.malformed, 'recovery key format');
    }
    return Uint8List.fromList([
      for (var i = 0; i < 64; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]);
  }
}
