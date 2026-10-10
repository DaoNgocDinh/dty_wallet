import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Địa chỉ API. Đổi khi chạy app:
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api   (máy ảo Android)
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000/api',
);

/// Lỗi trả về từ API (hoặc lỗi mạng) đã quy đổi sang thông điệp tiếng Việt.
class ApiException implements Exception {
  ApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Mã lỗi của server -> thông điệp hiển thị cho người dùng.
const Map<String, String> _apiErrorMessages = {
  'INVALID_CREDENTIALS': 'Tài khoản hoặc mật khẩu không đúng',
  'WRONG_PASSWORD': 'Mật khẩu cũ không đúng',
  'INVALID_INPUT': 'Thông tin không hợp lệ',
  'USERNAME_EXISTS': 'Tài khoản đã tồn tại',
  'EMAIL_EXISTS': 'Email đã được sử dụng',
  'NAME_TOO_LONG': 'Tên tài khoản quá dài',
};

class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient})
    : baseUrl = baseUrl ?? kApiBaseUrl,
      _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  static const Duration _timeout = Duration(seconds: 15);

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> get(String path, {String? token}) =>
      _send(() => _http.get(_uri(path), headers: _headers(token)));

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) => _send(
    () => _http.post(
      _uri(path),
      headers: _headers(token),
      body: jsonEncode(body ?? const {}),
    ),
  );

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) => _send(
    () => _http.put(
      _uri(path),
      headers: _headers(token),
      body: jsonEncode(body ?? const {}),
    ),
  );

  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('Máy chủ phản hồi quá lâu, vui lòng thử lại');
    } on http.ClientException {
      throw ApiException(
        'Không kết nối được máy chủ ($baseUrl). Hãy khởi động server trước.',
      );
    }

    final Map<String, dynamic> data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    final code = data['code'] as String?;
    throw ApiException(
      _apiErrorMessages[code] ??
          (data['error'] as String? ?? 'Lỗi ${response.statusCode}'),
      code: code,
      statusCode: response.statusCode,
    );
  }

  /// Đọc body JSON; body rỗng hoặc không phải JSON object thì quy về lỗi dễ hiểu.
  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Rơi xuống throw bên dưới.
    }
    throw ApiException(
      'Máy chủ trả về dữ liệu không hợp lệ (mã ${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  void dispose() => _http.close();
}
