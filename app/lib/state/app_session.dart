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

  Future<Map<String, dynamic>> fetchWallet() {
    final token = _token;
    if (token == null) {
      throw ApiException('Chưa đăng nhập');
    }
    return _authService.wallet(token);
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
        walletBalance: _user!.walletBalance,
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

  /// Nạp điện thoại / Data.
  Future<Map<String, dynamic>> mobileTopup({
    required String carrier,
    required String phoneNumber,
    required double amount,
    required String pin,
    String? dataPackage,
  }) {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.mobileTopup(
      token: token,
      carrier: carrier,
      phoneNumber: phoneNumber,
      amount: amount,
      pin: pin,
      dataPackage: dataPackage,
    );
  }

  /// Thanh toán hoá đơn.
  Future<Map<String, dynamic>> payBill({
    required String billType,
    required String customerCode,
    required double amount,
    required String paymentMethod,
    required String pin,
    String? content,
  }) {
    final token = _token;
    if (token == null) throw ApiException('Chưa đăng nhập');
    return _authService.payBill(
      token: token,
      billType: billType,
      customerCode: customerCode,
      amount: amount,
      paymentMethod: paymentMethod,
      pin: pin,
      content: content,
    );
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
