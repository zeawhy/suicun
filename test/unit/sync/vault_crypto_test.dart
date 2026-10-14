// test/unit/sync/vault_crypto_test.dart
// Stage C: tests for the sync vault encryption protocol.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/sync/vault_crypto.dart';

// Small KDF cost keeps tests fast; the protocol default is exercised in the
// header-format assertions.
const _fastKdf = VaultKdfParams(memoryKb: 64, iterations: 1, parallelism: 1);

Uint8List _unhex(String h) => Uint8List.fromList([
      for (var i = 0; i < h.length; i += 2)
        int.parse(h.substring(i, i + 2), radix: 16),
    ]);

Matcher _cryptoError(VaultCryptoCode code) => throwsA(
      isA<VaultCryptoError>().having((e) => e.code, 'code', code),
    );

Map<String, Object?> _payload(String rev, String type, String id) => {
      'revision_id': rev,
      'entity_type': type,
      'entity_id': id,
      'parents': ['p1', 'p2'],
      'created_at': '2026-01-02T03:04:05.000Z',
      'deleted': false,
      'snapshot': {
        'text': '你好 note',
        'n': 3,
        'nested': {
          'a': [1, 2]
        },
      },
    };

void main() {
  final aes = AesGcm.with256bits();
  final zeroKey = SecretKey(Uint8List(32));
  final zeroIv = Uint8List(12);

  group('AES-GCM primitive (NIST vectors)', () {
    test('empty plaintext', () async {
      final box =
          await aes.encrypt(const [], secretKey: zeroKey, nonce: zeroIv);
      expect(box.cipherText, isEmpty);
      expect(box.mac.bytes, _unhex('530f8afbc74536b9a963b4f1c4cb738b'));
    });

    test('16 zero bytes', () async {
      final box =
          await aes.encrypt(Uint8List(16), secretKey: zeroKey, nonce: zeroIv);
      expect(box.cipherText, _unhex('cea7403d4d606b6e074ec5d3baf39d18'));
      expect(box.mac.bytes, _unhex('d0d1c8a799996bf0265b98b5d48ab919'));
    });

    test('decrypt known vector and reject tampering', () async {
      final ct = _unhex('cea7403d4d606b6e074ec5d3baf39d18');
      final mac = Mac(_unhex('d0d1c8a799996bf0265b98b5d48ab919'));
      final clear = await aes.decrypt(SecretBox(ct, nonce: zeroIv, mac: mac),
          secretKey: zeroKey);
      expect(clear, Uint8List(16));

      final bad = Uint8List.fromList(ct)..[0] ^= 1;
      expect(
        aes.decrypt(SecretBox(bad, nonce: zeroIv, mac: mac),
            secretKey: zeroKey),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });

  group('vault header', () {
    final crypto = VaultCrypto(random: Random(0));

    test('create/open roundtrip with password and recovery key', () async {
      final created =
          await crypto.createVault(password: 'correct horse', kdf: _fastKdf);
      expect(created.session.kvault, hasLength(32));

      final opened =
          await crypto.openWithPassword(created.headerJson, 'correct horse');
      expect(opened.kvault, created.session.kvault);
      expect(opened.vaultId, created.session.vaultId);

      final viaKey = await crypto.openWithRecoveryKey(
          created.headerJson, created.recoveryKey);
      expect(viaKey.kvault, created.session.kvault);
      // Parsing is lenient about case and separators.
      final viaKey2 = await crypto.openWithRecoveryKey(created.headerJson,
          created.recoveryKey.toUpperCase().replaceAll('-', ' '));
      expect(viaKey2.kvault, created.session.kvault);
    });

    test('header layout follows the spec', () async {
      final created = await crypto.createVault(password: 'pw');
      final json = jsonDecode(created.headerJson) as Map<String, dynamic>;
      expect(json['format'], 'suicun-vault-header');
      expect(json['protocol_version'], 1);
      expect(json['vault_id'],
          matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab]')));
      final kdf = json['kdf'] as Map<String, dynamic>;
      expect(kdf['memory_kb'], 65536);
      expect(kdf['iterations'], 3);
      expect(kdf['parallelism'], 1);
      expect(base64Decode(kdf['salt_b64'] as String), hasLength(16));
      final slots = json['slots'] as List<dynamic>;
      expect(slots.map((s) => s['type']), ['password', 'recovery']);
      expect(base64Decode(slots[0]['wrapped_b64'] as String), hasLength(48));
      expect(slots[1]['key_id'], matches(RegExp(r'^[0-9a-f]{8}$')));
      expect(created.headerJson.contains(created.recoveryKey), isFalse);
    });

    test('wrong password fails authentication', () async {
      final created = await crypto.createVault(password: 'pw1', kdf: _fastKdf);
      expect(crypto.openWithPassword(created.headerJson, 'pw2'),
          _cryptoError(VaultCryptoCode.wrongPasswordOrKey));
    });

    test('wrong or corrupted recovery key', () async {
      final created = await crypto.createVault(password: 'pw', kdf: _fastKdf);
      expect(crypto.openWithRecoveryKey(created.headerJson, 'abcd-efgh'),
          _cryptoError(VaultCryptoCode.malformed));
      final other = VaultCrypto.formatRecoveryKey(Uint8List(32));
      expect(crypto.openWithRecoveryKey(created.headerJson, other),
          _cryptoError(VaultCryptoCode.wrongPasswordOrKey));
    });

    test('KDF parameter caps are enforced', () async {
      final created = await crypto.createVault(password: 'pw', kdf: _fastKdf);
      for (final entry in {
        'memory_kb': 1 << 30,
        'iterations': 17,
        'parallelism': 17,
      }.entries) {
        final json = jsonDecode(created.headerJson) as Map<String, dynamic>;
        (json['kdf'] as Map<String, dynamic>)[entry.key] = entry.value;
        expect(
            () => VaultHeader.parse(jsonEncode(json)),
            throwsA(isA<VaultCryptoError>().having(
                (e) => e.code, 'code', VaultCryptoCode.kdfParamsTooLarge)));
      }
    });

    test('tampered slot never yields a key', () async {
      final created = await crypto.createVault(password: 'pw', kdf: _fastKdf);
      final json = jsonDecode(created.headerJson) as Map<String, dynamic>;
      final slot = (json['slots'] as List<dynamic>)[0] as Map<String, dynamic>;
      final wrapped = base64Decode(slot['wrapped_b64'] as String);
      wrapped[0] ^= 0x01;
      slot['wrapped_b64'] = base64Encode(wrapped);
      expect(crypto.openWithPassword(jsonEncode(json), 'pw'),
          _cryptoError(VaultCryptoCode.wrongPasswordOrKey));
    });

    test('slot is bound to vault id via AAD', () async {
      final created = await crypto.createVault(password: 'pw', kdf: _fastKdf);
      final json = jsonDecode(created.headerJson) as Map<String, dynamic>;
      json['vault_id'] = 'another-vault';
      expect(crypto.openWithPassword(jsonEncode(json), 'pw'),
          _cryptoError(VaultCryptoCode.wrongPasswordOrKey));
    });

    test('unsupported protocol version is rejected before decrypting',
        () async {
      final created = await crypto.createVault(password: 'pw', kdf: _fastKdf);
      final json = jsonDecode(created.headerJson) as Map<String, dynamic>;
      json['protocol_version'] = 99;
      expect(crypto.openWithPassword(jsonEncode(json), 'pw'),
          _cryptoError(VaultCryptoCode.unsupportedVersion));
    });

    test('malformed headers', () {
      expect(() => VaultHeader.parse('not json'),
          throwsA(isA<VaultCryptoError>()));
      expect(() => VaultHeader.parse('{"format":"x"}'),
          throwsA(isA<VaultCryptoError>()));
    });
  });

  group('revision objects', () {
    final crypto = VaultCrypto(random: Random(1));
    late VaultSession session;

    setUp(() async {
      session =
          (await crypto.createVault(password: 'pw', kdf: _fastKdf)).session;
    });

    test('roundtrip', () async {
      final payload = _payload('rev-1', 'record', 'rec-1');
      final bytes = await crypto.encryptRevision(
        session: session,
        revisionId: 'rev-1',
        entityType: 'record',
        entityId: 'rec-1',
        payload: payload,
      );
      final env = crypto.parseEnvelope(bytes);
      expect(env.vaultId, session.vaultId);
      expect(env.revisionId, 'rev-1');
      expect(env.entityType, 'record');
      expect(env.entityId, 'rec-1');
      expect(env.nonce, hasLength(12));
      expect(env.mac, hasLength(16));
      // Only ids are in cleartext; note content and parents are not.
      final text = utf8.decode(bytes);
      expect(text.contains('note'), isFalse);
      expect(text.contains('parents'), isFalse);

      final out =
          await crypto.decryptRevision(session: session, objectBytes: bytes);
      expect(out, payload);
    });

    test('fresh nonce per object', () async {
      Future<Uint8List> enc() => crypto.encryptRevision(
            session: session,
            revisionId: 'r',
            entityType: 'tag',
            entityId: 't',
            payload: _payload('r', 'tag', 't'),
          );
      final a = crypto.parseEnvelope(await enc());
      final b = crypto.parseEnvelope(await enc());
      expect(a.nonce, isNot(b.nonce));
    });

    Future<Map<String, dynamic>> envelopeJson() async {
      final bytes = await crypto.encryptRevision(
        session: session,
        revisionId: 'rev-1',
        entityType: 'record',
        entityId: 'rec-1',
        payload: _payload('rev-1', 'record', 'rec-1'),
      );
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    }

    Uint8List enc(Map<String, dynamic> j) =>
        Uint8List.fromList(utf8.encode(jsonEncode(j)));

    test('tampered ciphertext', () async {
      final j = await envelopeJson();
      final ct = base64Decode(j['ciphertext_b64'] as String);
      ct[0] ^= 1;
      j['ciphertext_b64'] = base64Encode(ct);
      expect(crypto.decryptRevision(session: session, objectBytes: enc(j)),
          _cryptoError(VaultCryptoCode.tampered));
    });

    test('AAD binds entity type, revision id and vault', () async {
      for (final change in <String, String>{
        'entity_type': 'tag',
        'revision_id': 'rev-2',
        'vault_id': 'other',
      }.entries) {
        final j = await envelopeJson();
        j[change.key] = change.value;
        expect(
          crypto.decryptRevision(session: session, objectBytes: enc(j)),
          throwsA(isA<VaultCryptoError>()),
          reason: change.key,
        );
      }
      final j = await envelopeJson();
      j['entity_type'] = 'tag';
      expect(crypto.decryptRevision(session: session, objectBytes: enc(j)),
          _cryptoError(VaultCryptoCode.tampered));
    });

    test('wrong key fails as tampered', () async {
      final bytes = await crypto.encryptRevision(
        session: session,
        revisionId: 'rev-1',
        entityType: 'record',
        entityId: 'rec-1',
        payload: _payload('rev-1', 'record', 'rec-1'),
      );
      final wrong =
          VaultSession(vaultId: session.vaultId, kvault: Uint8List(32));
      expect(crypto.decryptRevision(session: wrong, objectBytes: bytes),
          _cryptoError(VaultCryptoCode.tampered));
    });

    test('payload id mismatch is rejected on encrypt', () {
      expect(
        crypto.encryptRevision(
          session: session,
          revisionId: 'rev-1',
          entityType: 'record',
          entityId: 'rec-1',
          payload: _payload('other', 'record', 'rec-1'),
        ),
        throwsA(isA<VaultCryptoError>()),
      );
    });

    test('inner/outer id mismatch is rejected on decrypt', () async {
      // Craft a validly encrypted object whose payload disagrees with the
      // outer ids (as a malicious or buggy writer could produce).
      final nonce = Uint8List(12)..[0] = 7;
      final payload = _payload('other-rev', 'record', 'rec-1');
      final box = await aes.encrypt(
        utf8.encode(jsonEncode(payload)),
        secretKey: SecretKey(session.kvault),
        nonce: nonce,
        aad: utf8.encode('suicun/v1/object/${session.vaultId}/rev-1/record'),
      );
      final bytes = enc({
        'format': 'suicun-revision',
        'protocol_version': 1,
        'vault_id': session.vaultId,
        'revision_id': 'rev-1',
        'entity_type': 'record',
        'entity_id': 'rec-1',
        'nonce_b64': base64Encode(nonce),
        'ciphertext_b64': base64Encode([...box.cipherText, ...box.mac.bytes]),
      });
      expect(crypto.decryptRevision(session: session, objectBytes: bytes),
          _cryptoError(VaultCryptoCode.malformed));
    });

    test('envelope validation', () async {
      final base = await envelopeJson();
      Map<String, dynamic> with_(String k, Object? v) => {...base, k: v};

      // version 3 throws unsupportedVersion
      expect(
          () => crypto.parseEnvelope(enc(with_('protocol_version', 3))),
          throwsA(isA<VaultCryptoError>().having(
              (e) => e.code, 'code', VaultCryptoCode.unsupportedVersion)));
      expect(() => crypto.parseEnvelope(enc(with_('format', 'nope'))),
          throwsA(isA<VaultCryptoError>()));
      expect(() => crypto.parseEnvelope(enc(with_('entity_type', 'weird'))),
          throwsA(isA<VaultCryptoError>()));
      expect(() => crypto.parseEnvelope(enc(with_('revision_id', ''))),
          throwsA(isA<VaultCryptoError>()));
      expect(
          () => crypto.parseEnvelope(
              enc(with_('nonce_b64', base64Encode(Uint8List(8))))),
          throwsA(isA<VaultCryptoError>()));
      expect(
          () => crypto.parseEnvelope(
              enc(with_('ciphertext_b64', base64Encode(Uint8List(16))))),
          throwsA(isA<VaultCryptoError>()));
      final missing = {...base}..remove('entity_id');
      expect(() => crypto.parseEnvelope(enc(missing)),
          throwsA(isA<VaultCryptoError>()));
      expect(() => crypto.parseEnvelope(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<VaultCryptoError>()));
      expect(
          () => crypto.parseEnvelope(Uint8List(kMaxObjectBytes + 1)),
          throwsA(isA<VaultCryptoError>()
              .having((e) => e.code, 'code', VaultCryptoCode.payloadTooLarge)));
    });
  });

  group('recovery key format', () {
    test('format/parse roundtrip', () {
      final raw = Uint8List.fromList(List.generate(32, (i) => i * 7 % 256));
      final s = VaultCrypto.formatRecoveryKey(raw);
      expect(s, matches(RegExp(r'^([0-9a-f]{4}-){15}[0-9a-f]{4}$')));
      expect(VaultCrypto.parseRecoveryKey(s), raw);
    });

    test('invalid keys throw', () {
      expect(() => VaultCrypto.parseRecoveryKey('xyz'),
          throwsA(isA<VaultCryptoError>()));
      expect(() => VaultCrypto.parseRecoveryKey('ab' * 33),
          throwsA(isA<VaultCryptoError>()));
    });
  });

  group('v2 vault crypto', () {
    final crypto = VaultCrypto(random: Random(42));

    test('key object create/parse roundtrip and open with password/recovery', () async {
      final created = await crypto.createKeyObject(
        password: 'secure-password',
        kdf: _fastKdf,
        origin: 'created',
        createdByDevice: 'device-test',
      );
      expect(created.keyId, hasLength(16));
      expect(created.variant, hasLength(8));
      expect(created.kvault, hasLength(32));

      final parsed = VaultKeyObject.parse(created.keyJson);
      expect(parsed.protocolVersion, kVaultProtocolVersionV2);
      expect(parsed.keyId, created.keyId);
      expect(parsed.variant, created.variant);
      expect(parsed.origin, 'created');
      expect(parsed.createdByDevice, 'device-test');
      expect(parsed.slots, hasLength(2));

      // Open with password
      final unlockedPass = await crypto.openKeyObjectWithPassword(
        created.keyJson,
        'secure-password',
      );
      expect(unlockedPass.keyId, created.keyId);
      expect(unlockedPass.kvault, created.kvault);

      // Open with recovery key
      final unlockedRec = await crypto.openKeyObjectWithRecoveryKey(
        created.keyJson,
        created.recoveryKey,
      );
      expect(unlockedRec.keyId, created.keyId);
      expect(unlockedRec.kvault, created.kvault);

      // Wrong password fails
      expect(
        () => crypto.openKeyObjectWithPassword(created.keyJson, 'wrong-pass'),
        _cryptoError(VaultCryptoCode.wrongPasswordOrKey),
      );

      // Wrong recovery key fails
      final otherRecovery = VaultCrypto.formatRecoveryKey(Uint8List(32));
      expect(
        () => crypto.openKeyObjectWithRecoveryKey(created.keyJson, otherRecovery),
        _cryptoError(VaultCryptoCode.wrongPasswordOrKey),
      );
    });

    test('slot AAD binding tamper -> wrongPasswordOrKey', () async {
      final created = await crypto.createKeyObject(
        password: 'test-pwd',
        kdf: _fastKdf,
      );
      final map = jsonDecode(created.keyJson) as Map<String, dynamic>;
      // Tamper key_id in json to change unwrap AAD
      map['key_id'] = '0123456789abcdef';
      final tamperedJson = jsonEncode(map);

      expect(
        () => crypto.openKeyObjectWithPassword(tamperedJson, 'test-pwd'),
        _cryptoError(VaultCryptoCode.wrongPasswordOrKey),
      );
    });

    test('envelope v2 encrypt/decrypt roundtrip', () async {
      final created = await crypto.createKeyObject(password: 'pwd', kdf: _fastKdf);
      final payload = _payload('rev-201', 'record', 'rec-99');
      final encryptedBytes = await crypto.encryptRevisionV2(
        kvault: created.kvault,
        keyId: created.keyId,
        revisionId: 'rev-201',
        entityType: 'record',
        entityId: 'rec-99',
        payload: payload,
      );

      final envelope = crypto.parseEnvelope(encryptedBytes);
      expect(envelope.protocolVersion, kVaultProtocolVersionV2);
      expect(envelope.keyId, created.keyId);
      expect(envelope.vaultId, isNull);
      expect(envelope.revisionId, 'rev-201');

      final decrypted = await crypto.decryptRevisionV2(
        kvault: created.kvault,
        objectBytes: encryptedBytes,
      );
      expect(decrypted['revision_id'], 'rev-201');
      expect(decrypted['snapshot'], payload['snapshot']);
    });

    test('key_id mismatch / AAD tamper -> tampered', () async {
      final created = await crypto.createKeyObject(password: 'pwd', kdf: _fastKdf);
      final payload = _payload('rev-202', 'record', 'rec-99');
      final encryptedBytes = await crypto.encryptRevisionV2(
        kvault: created.kvault,
        keyId: created.keyId,
        revisionId: 'rev-202',
        entityType: 'record',
        entityId: 'rec-99',
        payload: payload,
      );

      final map = jsonDecode(utf8.decode(encryptedBytes)) as Map<String, dynamic>;
      map['key_id'] = 'fedcba9876543210';
      final tamperedBytes = Uint8List.fromList(utf8.encode(jsonEncode(map)));

      expect(
        () => crypto.decryptRevisionV2(
          kvault: created.kvault,
          objectBytes: tamperedBytes,
        ),
        _cryptoError(VaultCryptoCode.tampered),
      );
    });

    test('legacy decrypt via decryptLegacyRevision', () async {
      final v1Created = await crypto.createVault(password: 'v1pass', kdf: _fastKdf);
      final payload = _payload('rev-v1', 'record', 'rec-v1');
      final v1Bytes = await crypto.encryptRevision(
        session: v1Created.session,
        revisionId: 'rev-v1',
        entityType: 'record',
        entityId: 'rec-v1',
        payload: payload,
      );

      final decrypted = await crypto.decryptLegacyRevision(
        kvault: v1Created.session.kvault,
        legacyVaultId: v1Created.session.vaultId,
        objectBytes: v1Bytes,
      );
      expect(decrypted['revision_id'], 'rev-v1');
      expect(decrypted['entity_id'], 'rec-v1');

      // Wrong legacyVaultId throws malformed / legacy vault mismatch
      expect(
        () => crypto.decryptLegacyRevision(
          kvault: v1Created.session.kvault,
          legacyVaultId: 'other-vault-id',
          objectBytes: v1Bytes,
        ),
        _cryptoError(VaultCryptoCode.malformed),
      );
    });

    test('parseEnvelope rejects protocol_version 3 with unsupportedVersion', () {
      final badEnvelope = utf8.encode(jsonEncode({
        'format': 'suicun-revision',
        'protocol_version': 3,
        'key_id': '0123456789abcdef',
        'revision_id': 'rev-3',
        'entity_type': 'record',
        'entity_id': 'rec-3',
        'nonce_b64': base64Encode(Uint8List(12)),
        'ciphertext_b64': base64Encode(Uint8List(32)),
      }));

      expect(
        () => crypto.parseEnvelope(badEnvelope),
        throwsA(isA<VaultCryptoError>().having(
          (e) => e.code,
          'code',
          VaultCryptoCode.unsupportedVersion,
        )),
      );
    });

    test('MultiKeySession pickActiveKeyId returns lexicographic minimum', () {
      expect(MultiKeySession.pickActiveKeyId([]), '');
      expect(MultiKeySession.pickActiveKeyId(['b', 'a', 'c']), 'a');
      expect(MultiKeySession.pickActiveKeyId(['0002', '0001', '0003']), '0001');
    });
  });
}
