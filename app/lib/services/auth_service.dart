import 'api_client.dart';

/// Thông tin người dùng trả về từ server.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.walletBalance = 0,
    this.createdAt,
    this.hasPin = false,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id']?.toString() ?? '',
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0,
    createdAt: json['createdAt'] as String?,
    hasPin: json['hasPin'] as bool? ?? false,
  );

  final String id;
  final String name;
  final String email;
  final double walletBalance;
  final String? createdAt;
  final bool hasPin;
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
    final data = await _client.post(
      '/auth/login',
      body: {'name': account.trim(), 'password': password},
    );
    return AuthResult.fromJson(data);
  }

  /// Đăng ký tài khoản mới, email được server tự sinh từ tên tài khoản.
  Future<AuthResult> register({
    required String account,
    required String password,
  }) async {
    final data = await _client.post(
      '/auth/register',
      body: {'name': account.trim(), 'password': password},
    );
    return AuthResult.fromJson(data);
  }

  /// Gọi một API cần token để kiểm tra token còn hiệu lực hay không.
  Future<Map<String, dynamic>> wallet(String token) =>
      _client.get('/wallet', token: token);

  /// Đăng xuất: server xác nhận token hợp lệ, client tự xoá token đã lưu.
  Future<void> logout(String token) async {
    await _client.post('/auth/logout', token: token);
  }

  /// Đổi mật khẩu. [currentPassword] phải đúng mật khẩu hiện tại và
  /// [newPassword] phải khớp với [confirmNewPassword].
  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    await _client.post(
      '/auth/change-password',
      token: token,
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmNewPassword': confirmNewPassword,
      },
    );
  }

  /// Thiết lập hoặc đổi mã PIN giao dịch (4-6 chữ số).
  Future<void> setPin({
    required String token,
    required String password,
    required String pin,
  }) async {
    await _client.put(
      '/auth/pin',
      token: token,
      body: {'password': password, 'pin': pin},
    );
  }

  /// Lấy thông tin cá nhân của người dùng hiện tại từ server.
  Future<Map<String, dynamic>> profile(String token) =>
      _client.get('/auth/me', token: token);

  /// Lấy danh sách lịch sử giao dịch.
  Future<Map<String, dynamic>> transactions(String token) =>
      _client.get('/transactions/history', token: token);

  /// Lấy danh sách quỹ.
  Future<Map<String, dynamic>> funds(String token) =>
      _client.get('/funds', token: token);

  /// Tạo quỹ mới.
  Future<Map<String, dynamic>> createFund({
    required String token,
    required String name,
    required String fundType,
    required double targetAmount,
  }) =>
      _client.post(
        '/funds',
        token: token,
        body: {
          'name': name,
          'fundType': fundType,
          'targetAmount': targetAmount,
        },
      );

  /// Lấy danh sách hũ chi tiêu.
  Future<Map<String, dynamic>> spendingJars(String token) =>
      _client.get('/spending-jars', token: token);

  /// Nạp tiền vào ví.
  Future<Map<String, dynamic>> deposit({
    required String token,
    required double amount,
    required String source,
    required String paymentMethod,
  }) =>
      _client.post(
        '/wallet/deposits',
        token: token,
        body: {
          'amount': amount,
          'source': source,
          'paymentMethod': paymentMethod,
        },
      );

  /// Nạp điện thoại hoặc gói data.
  Future<Map<String, dynamic>> mobileTopup({
    required String token,
    required String carrier,
    required String phoneNumber,
    required double amount,
    required String pin,
    String? dataPackage,
  }) =>
      _client.post(
        dataPackage != null ? '/wallet/topups/data' : '/wallet/topups/mobile',
        token: token,
        body: {
          'carrier': carrier,
          'phoneNumber': phoneNumber,
          'amount': amount,
          'pin': pin,
          'dataPackage': ?dataPackage,
        },
      );

  /// Thanh toán hóa đơn (Điện, Nước, Internet...).
  Future<Map<String, dynamic>> payBill({
    required String token,
    required String billType,
    required String customerCode,
    required double amount,
    required String paymentMethod,
    required String pin,
    String? content,
  }) =>
      _client.post(
        '/wallet/bill-payments',
        token: token,
        body: {
          'billType': billType,
          'customerCode': customerCode,
          'amount': amount,
          'paymentMethod': paymentMethod,
          'pin': pin,
          'content': ?content,
        },
      );
}
