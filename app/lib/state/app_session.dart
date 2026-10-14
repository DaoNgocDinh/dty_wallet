import 'package:flutter/widgets.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';

/// Lưu trạng thái đăng nhập hiện tại (token + thông tin người dùng).
class AppSession extends ChangeNotifier {
  AppSession({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  String? _token;
  AuthUser? _user;
  DateTime? _loginTime;

  String? get token => _token;
  AuthUser? get user => _user;
  DateTime? get loginTime => _loginTime;
  bool get isLoggedIn => _token != null;

  Future<AuthResult> login({
    required String account,
    required String password,
  }) async {
    final result = await _authService.login(
      account: account,
      password: password,
    );
    _token = result.token;
    _user = result.user;
    _loginTime = DateTime.now();
    notifyListeners();
    return result;
  }

  /// Đăng ký tài khoản mới. Không tự lưu phiên: sau khi đăng ký app quay về
  /// màn hình đăng nhập để người dùng đăng nhập bằng tài khoản vừa tạo.
  Future<AuthResult> register({
    required String account,
    required String password,
  }) {
    return _authService.register(account: account, password: password);
  }

  Future<Map<String, dynamic>> fetchWallet() async {
    final token = _token;
    if (token == null) {
      throw ApiException('Chưa đăng nhập');
    }
    final res = await _authService.wallet(token);
    final balance = res['walletBalance'] ?? res['balance'];
    final serverRole = res['role'] as String?;
    if (_user != null) {
      final newBalance = balance != null ? (balance as num).toDouble() : _user!.walletBalance;
      final newRole = serverRole ?? _user!.role;
      if (_user!.walletBalance != newBalance || _user!.role != newRole) {
        _user = AuthUser(
          id: _user!.id,
          name: _user!.name,
          email: _user!.email,
          phoneNumber: _user!.phoneNumber,
          walletBalance: newBalance,
          role: newRole,
          createdAt: _user!.createdAt,
          hasPin: _user!.hasPin,
        );
        notifyListeners();
      }
    }
    return res;
  }

  /// Đăng xuất: xoá phiên ngay trên máy, sau đó báo server (nếu mạng OK).
  Future<void> logout() async {
    final token = _token;
    _token = null;
    _user = null;
    notifyListeners();

    if (token == null) return;
    try {
      await _authService.logout(token);
    } on ApiException {
      // Token đã xoá ở client nên vẫn đăng xuất được khi server không phản hồi.
    }
  }

  /// Đổi mật khẩu của tài khoản đang đăng nhập.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    final token = _token;
    if (token == null) {
      throw ApiException('Chưa đăng nhập');
    }
    await _authService.changePassword(
      token: token,
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmNewPassword: confirmNewPassword,
    );
  }

  /// Cập nhật mã PIN giao dịch.
  Future<void> setPin({
    required String password,
    required String pin,
  }) async {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    await _authService.setPin(token: token, password: password, pin: pin);
    if (_user != null) {
      _user = AuthUser(
        id: _user!.id,
        name: _user!.name,
        email: _user!.email,
        phoneNumber: _user!.phoneNumber,
        walletBalance: _user!.walletBalance,
        role: _user!.role,
        createdAt: _user!.createdAt,
        hasPin: true,
      );
      notifyListeners();
    }
  }

  /// Lấy thông tin cá nhân chi tiết.
  Future<Map<String, dynamic>> fetchProfile() async {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    final res = await _authService.profile(token);
    if (res['user'] is Map<String, dynamic>) {
      _user = AuthUser.fromJson(res['user'] as Map<String, dynamic>);
      notifyListeners();
    }
    return res;
  }

  /// Lấy danh sách lịch sử giao dịch.
  Future<Map<String, dynamic>> fetchTransactions() {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.transactions(token);
  }

  /// Lấy danh sách quỹ.
  Future<Map<String, dynamic>> fetchFunds() {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.funds(token);
  }

  /// Tạo quỹ mới.
  /// Quỹ "Cặp đôi" bắt buộc phải chọn [partnerId] là người dùng khác.
  Future<Map<String, dynamic>> createFund({
    required String name,
    required String fundType,
    double? targetAmount,
    DateTime? completionDate,
    String? partnerId,
  }) {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.createFund(
      token: token,
      name: name,
      fundType: fundType,
      targetAmount: targetAmount,
      completionDate: completionDate,
      partnerId: partnerId,
    );
  }

  /// Rút tiền từ quỹ về ví cá nhân (chỉ chủ quỹ).
  Future<Map<String, dynamic>> withdrawFund({
    required String fundId,
    required double amount,
    String? note,
  }) async {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    final res = await _authService.withdrawFund(
      token: token,
      fundId: fundId,
      amount: amount,
      note: note,
    );
    if (res['walletBalance'] != null && _user != null) {
      final newBalance = (res['walletBalance'] as num).toDouble();
      _user = AuthUser(
        id: _user!.id,
        name: _user!.name,
        email: _user!.email,
        phoneNumber: _user!.phoneNumber,
        walletBalance: newBalance,
        role: _user!.role,
        createdAt: _user!.createdAt,
        hasPin: _user!.hasPin,
      );
      notifyListeners();
    }
    return res;
  }

  /// Danh sách người dùng để chọn làm người cùng lập quỹ cặp đôi.
  Future<Map<String, dynamic>> fetchPartnerCandidates({String? query}) {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.partnerCandidates(token: token, query: query);
  }

  /// Xoá quỹ theo ID.
  Future<Map<String, dynamic>> deleteFund(String fundId) {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.deleteFund(token: token, fundId: fundId);
  }

  /// Rời quỹ theo ID (dành cho thành viên quỹ).
  Future<Map<String, dynamic>> leaveFund(String fundId) {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.leaveFund(token: token, fundId: fundId);
  }

  /// Lấy thông tin chi tiết một quỹ.
  Future<Map<String, dynamic>> fetchFundDetails(String fundId) {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.fundDetails(token: token, fundId: fundId);
  }

  /// Góp tiền vào quỹ.
  Future<Map<String, dynamic>> contributeFund({
    required String fundId,
    required double amount,
    String? note,
  }) async {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    final res = await _authService.contributeFund(
      token: token,
      fundId: fundId,
      amount: amount,
      note: note,
    );
    if (res['walletBalance'] != null && _user != null) {
      final newBalance = (res['walletBalance'] as num).toDouble();
      _user = AuthUser(
        id: _user!.id,
        name: _user!.name,
        email: _user!.email,
        phoneNumber: _user!.phoneNumber,
        walletBalance: newBalance,
        role: _user!.role,
        createdAt: _user!.createdAt,
        hasPin: _user!.hasPin,
      );
      notifyListeners();
    }
    return res;
  }

  /// Lấy danh sách hũ chi tiêu.
  Future<Map<String, dynamic>> fetchSpendingJars() {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.spendingJars(token);
  }

  /// Nạp tiền vào ví.
  Future<Map<String, dynamic>> deposit({
    required double amount,
    required String source,
    required String paymentMethod,
  }) {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.deposit(
      token: token,
      amount: amount,
      source: source,
      paymentMethod: paymentMethod,
    );
  }

  /// Lấy danh sách gói Data từ nhà mạng (Subflow 8.2.1).
  Future<List<Map<String, dynamic>>> fetchDataPackages({String? carrier}) {
    return _authService.getDataPackages(token: _token, carrier: carrier);
  }

  /// Nạp điện thoại / Data (Use Case 08).
  Future<Map<String, dynamic>> mobileTopup({
    required String carrier,
    required String phoneNumber,
    required double amount,
    required String pin,
    String? dataPackage,
  }) async {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    final res = await _authService.mobileTopup(
      token: token,
      carrier: carrier,
      phoneNumber: phoneNumber,
      amount: amount,
      pin: pin,
      dataPackage: dataPackage,
    );
    if (res['walletBalance'] != null && _user != null) {
      final newBalance = (res['walletBalance'] as num).toDouble();
      _user = AuthUser(
        id: _user!.id,
        name: _user!.name,
        email: _user!.email,
        phoneNumber: _user!.phoneNumber,
        walletBalance: newBalance,
        role: _user!.role,
        createdAt: _user!.createdAt,
        hasPin: _user!.hasPin,
      );
      notifyListeners();
    }
    return res;
  }

  /// Lấy thông tin hóa đơn từ API đối tác (Use Case 07 - Bước 8).
  Future<Map<String, dynamic>> fetchBillInfo({
    required String paymentMethod,
    String? billType,
    String? customerCode,
    String? qrData,
  }) {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.getBillInfo(
      token: token,
      paymentMethod: paymentMethod,
      billType: billType,
      customerCode: customerCode,
      qrData: qrData,
    );
  }

  /// Thanh toán hoá đơn (Use Case 07).
  Future<Map<String, dynamic>> payBill({
    required String billType,
    required String customerCode,
    required String paymentMethod,
    required String pin,
    double? amount,
    String? qrData,
    String? content,
  }) async {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    final res = await _authService.payBill(
      token: token,
      billType: billType,
      customerCode: customerCode,
      paymentMethod: paymentMethod,
      pin: pin,
      amount: amount,
      qrData: qrData,
      content: content,
    );
    // Bước 15: Cập nhật số dư ví sau khi thanh toán thành công
    if (res['walletBalance'] != null && _user != null) {
      final newBalance = (res['walletBalance'] as num).toDouble();
      _user = AuthUser(
        id: _user!.id,
        name: _user!.name,
        email: _user!.email,
        phoneNumber: _user!.phoneNumber,
        walletBalance: newBalance,
        role: _user!.role,
        createdAt: _user!.createdAt,
        hasPin: _user!.hasPin,
      );
      notifyListeners();
    }
    return res;
  }

  /// Lấy danh sách ứng viên có thể mời vào quỹ.
  Future<Map<String, dynamic>> fetchFundCandidates({
    required String fundId,
    String? query,
  }) {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.fundCandidates(
      token: token,
      fundId: fundId,
      query: query,
    );
  }

  /// Gửi lời mời tham gia quỹ.
  Future<Map<String, dynamic>> sendFundInvite({
    required String fundId,
    String? inviteeId,
    String? phoneNumber,
    String? name,
  }) {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.sendFundInvite(
      token: token,
      fundId: fundId,
      inviteeId: inviteeId,
      phoneNumber: phoneNumber,
      name: name,
    );
  }

  /// Lấy danh sách lời mời nhận được.
  Future<Map<String, dynamic>> fetchMyInvitations({String? status}) {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.myInvitations(token: token, status: status);
  }

  /// Chấp nhận lời mời tham gia quỹ.
  Future<Map<String, dynamic>> acceptInvitation(String invitationId) {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.acceptInvitation(
      token: token,
      invitationId: invitationId,
    );
  }

  /// Từ chối lời mời tham gia quỹ.
  Future<Map<String, dynamic>> rejectInvitation(String invitationId) {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.rejectInvitation(
      token: token,
      invitationId: invitationId,
    );
  }

  /// Lấy danh sách thông báo và số lượng chưa đọc.
  Future<Map<String, dynamic>> fetchNotifications() {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.notifications(token);
  }

  /// Đánh dấu thông báo đã đọc.
  Future<Map<String, dynamic>> markNotificationRead(String notificationId) {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.markNotificationRead(
      token: token,
      notificationId: notificationId,
    );
  }

  /// Đánh dấu tất cả thông báo đã đọc.
  Future<Map<String, dynamic>> markAllNotificationsRead() {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.markAllNotificationsRead(token);
  }

  /// Lấy danh sách tất cả tài khoản người dùng (chỉ dành cho Admin).
  Future<Map<String, dynamic>> fetchAdminUsers({String? search}) {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.adminUsers(token, search: search);
  }
}

/// Cung cấp [AppSession] cho toàn cây widget.
class AppScope extends InheritedNotifier<AppSession> {
  const AppScope({super.key, required AppSession session, required super.child})
    : super(notifier: session);

  static AppSession of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope chưa được bọc quanh widget này');
    return scope!.notifier!;
  }
}
