import 'api_client.dart';
import 'fund_service.dart';

export 'fund_service.dart';

/// Thông tin người dùng trả về từ server.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.walletBalance = 0,
    this.role = 'user',
    this.createdAt,
    this.hasPin = false,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id']?.toString() ?? '',
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0,
    role: json['role'] as String? ?? 'user',
    createdAt: json['createdAt'] as String?,
    hasPin: json['hasPin'] as bool? ?? false,
  );

  final String id;
  final String name;
  final String email;
  final double walletBalance;
  final String role;
  final String? createdAt;
  final bool hasPin;

  bool get isAdmin => role == 'admin' || name.trim().toLowerCase() == 'admin';
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
  AuthService({ApiClient? client, FundService? fundService})
      : _client = client ?? ApiClient(),
        _fundService = fundService ?? FundService(client: client ?? ApiClient());

  final ApiClient _client;
  final FundService _fundService;

  FundService get fundService => _fundService;

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

  /// Lấy danh sách quỹ (Ủy quyền qua FundService).
  Future<Map<String, dynamic>> funds(String token) =>
      _fundService.funds(token);

  /// Tạo quỹ mới (Ủy quyền qua FundService).
  Future<Map<String, dynamic>> createFund({
    required String token,
    required String name,
    required String fundType,
    double? targetAmount,
    DateTime? completionDate,
  }) =>
      _fundService.createFund(
        token: token,
        name: name,
        fundType: fundType,
        targetAmount: targetAmount,
        completionDate: completionDate,
      );

  /// Xoá quỹ theo ID (Ủy quyền qua FundService).
  Future<Map<String, dynamic>> deleteFund({
    required String token,
    required String fundId,
  }) =>
      _fundService.deleteFund(token: token, fundId: fundId);

  /// Lấy thông tin chi tiết một quỹ (Ủy quyền qua FundService).
  Future<Map<String, dynamic>> fundDetails({
    required String token,
    required String fundId,
  }) =>
      _fundService.fundDetails(token: token, fundId: fundId);

  /// Góp tiền vào quỹ (Ủy quyền qua FundService).
  Future<Map<String, dynamic>> contributeFund({
    required String token,
    required String fundId,
    required double amount,
    String? note,
  }) =>
      _fundService.contributeFund(
        token: token,
        fundId: fundId,
        amount: amount,
        note: note,
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

  /// Lấy danh sách ứng viên có thể mời vào quỹ (Ủy quyền qua FundService).
  Future<Map<String, dynamic>> fundCandidates({
    required String token,
    required String fundId,
    String? query,
  }) =>
      _fundService.fundCandidates(token: token, fundId: fundId, query: query);

  /// Gửi lời mời tham gia quỹ (Ủy quyền qua FundService).
  Future<Map<String, dynamic>> sendFundInvite({
    required String token,
    required String fundId,
    String? inviteeId,
    String? phoneNumber,
    String? name,
  }) =>
      _fundService.sendFundInvite(
        token: token,
        fundId: fundId,
        inviteeId: inviteeId,
        phoneNumber: phoneNumber,
        name: name,
      );

  /// Lấy danh sách lời mời nhận được (Ủy quyền qua FundService).
  Future<Map<String, dynamic>> myInvitations({
    required String token,
    String? status,
  }) =>
      _fundService.myInvitations(token: token, status: status);

  /// Chấp nhận lời mời tham gia quỹ (Ủy quyền qua FundService).
  Future<Map<String, dynamic>> acceptInvitation({
    required String token,
    required String invitationId,
  }) =>
      _fundService.acceptInvitation(token: token, invitationId: invitationId);

  /// Từ chối lời mời tham gia quỹ (Ủy quyền qua FundService).
  Future<Map<String, dynamic>> rejectInvitation({
    required String token,
    required String invitationId,
  }) =>
      _fundService.rejectInvitation(token: token, invitationId: invitationId);

  /// Lấy danh sách thông báo và số lượng chưa đọc.
  Future<Map<String, dynamic>> notifications(String token) =>
      _client.get('/notifications', token: token);

  /// Đánh dấu thông báo đã đọc.
  Future<Map<String, dynamic>> markNotificationRead({
    required String token,
    required String notificationId,
  }) =>
      _client.put('/notifications/$notificationId/read', token: token);

  /// Đánh dấu tất cả thông báo đã đọc.
  Future<Map<String, dynamic>> markAllNotificationsRead(String token) =>
      _client.put('/notifications/read-all', token: token);

  /// Lấy danh sách tất cả tài khoản người dùng (chỉ dành cho Admin).
  Future<Map<String, dynamic>> adminUsers(String token, {String? search}) {
    final queryParam = (search != null && search.trim().isNotEmpty)
        ? '?search=${Uri.encodeComponent(search.trim())}'
        : '';
    return _client.get('/admin/users$queryParam', token: token);
  }
}
