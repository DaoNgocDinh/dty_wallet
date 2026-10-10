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

  String? get token => _token;
  AuthUser? get user => _user;
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
    notifyListeners();
    return result;
  }

  Future<AuthResult> register({
    required String account,
    required String password,
  }) async {
    final result = await _authService.register(
      account: account,
      password: password,
    );
    _token = result.token;
    _user = result.user;
    notifyListeners();
    return result;
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
