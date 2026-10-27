import 'dart:io';

String? normalizeHttpProxy(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(
    trimmed.contains('://') ? trimmed : 'http://$trimmed',
  );
  if (uri == null ||
      uri.scheme != 'http' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  final port = uri.hasPort ? uri.port : 80;
  if (port <= 0 || port > 65535) return null;
  return '${uri.host}:$port';
}

HttpClient createHttpClient({String proxy = ''}) {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..userAgent = 'Kuangshuati-Android/1';
  final proxyAddress = normalizeHttpProxy(proxy);
  if (proxyAddress != null) {
    client.findProxy = (_) => 'PROXY $proxyAddress';
  }
  return client;
}
