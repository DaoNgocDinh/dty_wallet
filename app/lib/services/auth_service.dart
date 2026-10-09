import 'api_client.dart';

/// Thông tin người dùng trả về từ server.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.walletBalance = 0,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0,
      );

  final String id;
  final String name;
  final String email;
  final double walletBalance;
}

class AuthResult {
  const AuthResult({required this.token, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        token: json['token'] as String? ?? '',
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
      );

  final String token;
  final AuthUser user;
}

class AuthService {
  AuthService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Đăng nhập bằng **tên tài khoản** (không phải email).
  Future<AuthResult> login({
    required String account,
    required String password,
  }) async {
    final data = await _client.post('/auth/login', body: {
      'name': account.trim(),
      'password': password,
    });
    return AuthResult.fromJson(data);
  }

  /// Đăng ký tài khoản mới, email được server tự sinh từ tên tài khoản.
  Future<AuthResult> register({
    required String account,
    required String password,
  }) async {
    final data = await _client.post('/auth/register', body: {
      'name': account.trim(),
      'password': password,
    });
    return AuthResult.fromJson(data);
  }

  /// Gọi một API cần token để kiểm tra token còn hiệu lực hay không.
  Future<Map<String, dynamic>> wallet(String token) =>
      _client.get('/wallet', token: token);
}