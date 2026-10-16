// lib/features/records/presentation/clipboard_sniffer.dart

enum SniffedType {
  idDocument,
  address,
  link,
}

class SniffedClipboardData {
  const SniffedClipboardData({
    required this.type,
    required this.rawText,
    required this.previewText,
    required this.bannerLabel,
    required this.actionLabel,
    required this.templateId,
    required this.initialBody,
  });

  final SniffedType type;
  final String rawText;
  final String previewText;
  final String bannerLabel;
  final String actionLabel;
  final String templateId;
  final String initialBody;
}

final _idCardRegExp = RegExp(
  r'(?:^|[^\d])([1-9]\d{5}(?:18|19|20)\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])\d{3}[\dXx])(?:$|[^\dXx])',
);

final _urlRegExp = RegExp(r'https?:\/\/[^\s]+');

final _phoneRegExp = RegExp(r'(?:(?:\+?86)?\s*)?(1[3-9]\d{9})');

final _addressKeywordRegExp = RegExp(
  r'(?:省|市|区|县|街道|镇|乡|路|弄|号|大厦|小区|单元|室)',
);

/// Sniffs [rawText] locally for sensitive structured information:
/// 1. 18-digit Chinese Resident ID number
/// 2. Address / Phone + Address
/// 3. HTTP(S) URL link
///
/// Returns [SniffedClipboardData] if matched, or `null` otherwise.
SniffedClipboardData? sniffClipboardText(String rawText) {
  final text = rawText.trim();
  if (text.isEmpty || text.length < 5) return null;

  // 1. Check 18-digit ID card
  final idMatch = _idCardRegExp.firstMatch(text);
  if (idMatch != null) {
    final idNumber = idMatch.group(1)!;
    final masked = idNumber.length >= 8
        ? '${idNumber.substring(0, 4)}****${idNumber.substring(idNumber.length - 4)}'
        : idNumber;
    return SniffedClipboardData(
      type: SniffedType.idDocument,
      rawText: text,
      previewText: masked,
      bannerLabel: '检测到证件号',
      actionLabel: '存为证件',
      templateId: 'id_document',
      initialBody: '证件类型：身份证\n证件号码：$idNumber\n姓名：',
    );
  }

  // 2. Check Address (with or without Phone)
  // Must contain address keywords and be of reasonable length (>= 6)
  if (_addressKeywordRegExp.hasMatch(text) && text.length >= 6) {
    final phoneMatch = _phoneRegExp.firstMatch(text);
    final phone = phoneMatch?.group(1);
    var cleanAddress = text;
    if (phone != null) {
      cleanAddress = cleanAddress.replaceFirst(phoneMatch!.group(0)!, '').trim();
    }
    // Clean leading/trailing symbols
    cleanAddress = cleanAddress.replaceAll(RegExp(r'^[\s,，:：\-—]+|[\s,，:：\-—]+$'), '');

    final preview = text.length > 16 ? '${text.substring(0, 16)}…' : text;
    final bodyBuffer = StringBuffer();
    bodyBuffer.writeln('姓名：');
    bodyBuffer.writeln('电话：${phone ?? ''}');
    bodyBuffer.writeln('地址：$cleanAddress');

    return SniffedClipboardData(
      type: SniffedType.address,
      rawText: text,
      previewText: preview,
      bannerLabel: '检测到地址',
      actionLabel: '存为地址',
      templateId: 'address',
      initialBody: bodyBuffer.toString(),
    );
  }

  // 3. Check HTTP(S) Link
  final urlMatch = _urlRegExp.firstMatch(text);
  if (urlMatch != null) {
    final url = urlMatch.group(0)!;
    final parsedHost = Uri.tryParse(url)?.host;
    final host = (parsedHost != null && parsedHost.isNotEmpty) ? parsedHost : url;
    return SniffedClipboardData(
      type: SniffedType.link,
      rawText: text,
      previewText: host,
      bannerLabel: '检测到链接',
      actionLabel: '存为网站账号',
      templateId: 'password',
      initialBody: '网站/应用：$url\n用户名：\n密码：',
    );
  }

  return null;
}
