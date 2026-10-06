// lib/features/sync/sync_errors.dart
// Stage C: user-facing sync error codes with zh/en messages (no secrets).

import 'sync_provider.dart';

enum SyncErrorCode {
  networkUnavailable,
  timeout,
  unauthorized,
  forbidden,
  objectNotFound,
  vaultNotFound,
  headerMismatch,
  unsupportedProtocol,
  wrongPasswordOrKey,
  tamperedData,
  kdfParamsTooLarge,
  malformedHeader,
  malformedObject,
  preconditionFailed,
  contentConflict,
  rateLimited,
  insufficientStorage,
  serverError,
  conditionalWriteUnsupported,
  verifyFailed,
  redirectBlocked,
  payloadTooLarge,
  notJoined,
  needsMigration,
  needsPassword,
  unknown,
}

class SyncError implements Exception {
  const SyncError(this.code, [this.detail = '']);

  final SyncErrorCode code;

  /// Safe diagnostic only (status codes, counts, random task ids); never
  /// secrets or note plaintext.
  final String detail;

  /// Localized user-facing message. Never contains [detail] or any secret.
  String message({required bool english}) {
    final pair = _messages[code]!;
    return english ? pair.$2 : pair.$1;
  }

  static const Map<SyncErrorCode, (String, String)> _messages = {
    SyncErrorCode.networkUnavailable: (
      '网络不可用，将在恢复后重试',
      'Network unavailable; will retry when it is back',
    ),
    SyncErrorCode.timeout: (
      '连接服务器超时，稍后将重试',
      'The server timed out; will retry later',
    ),
    SyncErrorCode.unauthorized: (
      'WebDAV 账号或密码错误，同步已暂停',
      'WebDAV username or password is wrong; sync paused',
    ),
    SyncErrorCode.forbidden: (
      '没有权限访问该 WebDAV 目录，同步已暂停',
      'No permission to access the WebDAV directory; sync paused',
    ),
    SyncErrorCode.objectNotFound: (
      '云端缺少所需的数据对象',
      'A required object is missing on the server',
    ),
    SyncErrorCode.vaultNotFound: (
      '云端目录中没有找到同步库',
      'No sync vault was found in the server directory',
    ),
    SyncErrorCode.headerMismatch: (
      '云端同步库与本机记录不一致，请确认后重新连接',
      'The server vault does not match this device; please reconnect',
    ),
    SyncErrorCode.unsupportedProtocol: (
      '同步协议版本不受支持，请升级应用',
      'Unsupported sync protocol version; please update the app',
    ),
    SyncErrorCode.wrongPasswordOrKey: (
      '同步密码或恢复密钥错误',
      'Wrong sync password or recovery key',
    ),
    SyncErrorCode.tamperedData: (
      '云端数据校验失败，可能已损坏或被篡改',
      'Server data failed verification; it may be corrupted or tampered with',
    ),
    SyncErrorCode.kdfParamsTooLarge: (
      '云端密钥参数过大，已拒绝处理',
      'Server key-derivation parameters are too large; refused',
    ),
    SyncErrorCode.malformedHeader: (
      '云端同步库头文件格式不正确',
      'The vault header on the server is malformed',
    ),
    SyncErrorCode.malformedObject: (
      '云端数据对象格式不正确',
      'A data object on the server is malformed',
    ),
    SyncErrorCode.preconditionFailed: (
      '云端数据已被其他设备更新，将重新同步',
      'Server data changed on another device; will resync',
    ),
    SyncErrorCode.contentConflict: (
      '云端已存在内容不同的同名对象',
      'A different object with the same name already exists on the server',
    ),
    SyncErrorCode.rateLimited: (
      '服务器请求过于频繁，稍后将重试',
      'The server is rate limiting requests; will retry later',
    ),
    SyncErrorCode.insufficientStorage: (
      'WebDAV 存储空间不足，同步已暂停',
      'WebDAV storage is full; sync paused',
    ),
    SyncErrorCode.serverError: (
      'WebDAV 服务器出错，稍后将重试',
      'WebDAV server error; will retry later',
    ),
    SyncErrorCode.conditionalWriteUnsupported: (
      '该服务器不支持条件写入，无法安全同步',
      'This server does not support conditional writes; cannot sync safely',
    ),
    SyncErrorCode.verifyFailed: (
      '写入后校验失败，请稍后重试',
      'Verification after writing failed; please retry later',
    ),
    SyncErrorCode.redirectBlocked: (
      '服务器重定向到了其他地址，已出于安全阻止',
      'The server redirected to another origin; blocked for safety',
    ),
    SyncErrorCode.payloadTooLarge: (
      '云端数据过大，已拒绝处理',
      'Server data is too large; refused',
    ),
    SyncErrorCode.notJoined: (
      '尚未加入同步库，请先创建或加入',
      'Not joined to a sync vault yet',
    ),
    SyncErrorCode.needsMigration: (
      '发现旧协议同步库，需要先迁移',
      'Legacy sync vault found; migration is required',
    ),
    SyncErrorCode.needsPassword: (
      '需要输入同步密码以继续同步',
      'Sync password is required to continue syncing',
    ),
    SyncErrorCode.unknown: (
      '同步时发生未知错误',
      'An unknown sync error occurred',
    ),
  };

  @override
  String toString() =>
      'SyncError(${code.name}${detail.isEmpty ? '' : ': $detail'})';
}

/// Localized user-facing message for [SyncProviderException].
/// Never contains [e.detail] or secrets.
String providerErrorMessage(SyncProviderException e, {required bool english}) {
  switch (e.kind) {
    case ProviderErrorKind.unauthorized:
      return english
          ? 'WebDAV username or password is wrong'
          : 'WebDAV 账号或密码错误';
    case ProviderErrorKind.forbidden:
      return english
          ? 'No permission to access this directory; check directory permissions'
          : '没有权限访问该目录，请检查目录权限';
    case ProviderErrorKind.notFound:
      return english
          ? 'Creating the remote directory…'
          : '云端目录尚未创建，正在创建…';
    case ProviderErrorKind.rateLimited:
      return english
          ? 'Server is rate limiting; retry later'
          : '服务器请求过于频繁，稍后重试';
    case ProviderErrorKind.insufficientStorage:
      return english
          ? 'WebDAV storage is full'
          : 'WebDAV 存储空间不足';
    case ProviderErrorKind.network:
    case ProviderErrorKind.timeout:
      return english
          ? 'Network unavailable; check your connection and retry'
          : '网络不可用，请检查网络后重试';
    default:
      return english
          ? 'Sync connection failed; please retry later'
          : '同步连接失败，请稍后重试';
  }
}
