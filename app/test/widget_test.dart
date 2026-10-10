// Widget test cho luồng đăng nhập / đăng ký (dùng AuthService giả, không gọi API thật).

import 'package:app/main.dart';
import 'package:app/screens/change_password_screen.dart';
import 'package:app/screens/home_screen.dart';
import 'package:app/screens/login_screen.dart';
import 'package:app/screens/profile_screen.dart';
import 'package:app/screens/register_screen.dart';
import 'package:app/services/api_client.dart';
import 'package:app/services/auth_service.dart';
import 'package:app/state/app_session.dart';
import 'package:app/theme/app_theme.dart';
import 'package:app/widgets/app_button.dart';
import 'package:app/widgets/back_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// AuthService giả: trả về token nếu mật khẩu là "123456", ngược lại báo lỗi.
class FakeAuthService implements AuthService {
  FakeAuthService({required this.acceptedPassword});

  final String acceptedPassword;
  String? currentPassword = 'mat-khau-cu';

  @override
  Future<AuthResult> login({
    required String account,
    required String password,
  }) async {
    if (password != acceptedPassword) {
      throw ApiException('Tài khoản hoặc mật khẩu không đúng',
          code: 'INVALID_CREDENTIALS', statusCode: 401);
    }
    return _result(account);
  }

  @override
  Future<AuthResult> register({
    required String account,
    required String password,
  }) async {
    if (account.toLowerCase() == 'admin') {
      throw ApiException('Tài khoản đã tồn tại',
          code: 'USERNAME_EXISTS', statusCode: 409);
    }
    return _result(account);
  }

  @override
  Future<Map<String, dynamic>> wallet(String token) async => {'balance': 1000000};

  @override
  Future<void> logout(String token) async {}

  @override
  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    if (currentPassword != this.currentPassword) {
      throw ApiException('Mật khẩu cũ không đúng',
          code: 'WRONG_PASSWORD', statusCode: 400);
    }
    if (newPassword != confirmNewPassword) {
      throw ApiException('Xác thực mật khẩu không khớp', code: 'INVALID_INPUT');
    }
    this.currentPassword = newPassword;
  }

  @override
  Future<void> setPin({
    required String token,
    required String password,
    required String pin,
  }) async {}

  @override
  Future<Map<String, dynamic>> profile(String token) async => {
        'user': {
          'id': '65f0000000000000000000aa',
          'name': 'admin',
          'email': 'admin@gmail.com',
          'walletBalance': 1000000,
          'hasPin': false,
        }
      };

  @override
  Future<Map<String, dynamic>> transactions(String token) async => {'data': []};

  @override
  Future<Map<String, dynamic>> funds(String token) async => {'data': []};

  @override
  Future<Map<String, dynamic>> createFund({
    required String token,
    required String name,
    required String fundType,
    required double targetAmount,
  }) async => {};

  @override
  Future<Map<String, dynamic>> spendingJars(String token) async => {'data': []};

  @override
  Future<Map<String, dynamic>> deposit({
    required String token,
    required double amount,
    required String source,
    required String paymentMethod,
  }) async => {'message': 'Deposit success'};

  @override
  Future<Map<String, dynamic>> mobileTopup({
    required String token,
    required String carrier,
    required String phoneNumber,
    required double amount,
    required String pin,
    String? dataPackage,
  }) async => {'message': 'Topup success'};

  @override
  Future<Map<String, dynamic>> payBill({
    required String token,
    required String billType,
    required String customerCode,
    required double amount,
    required String paymentMethod,
    required String pin,
    String? content,
  }) async => {'message': 'Bill paid'};

  AuthResult _result(String account) => AuthResult(
        token: 'fake-jwt-token-for-$account',
        user: AuthUser(
          id: '65f0000000000000000000aa',
          name: account,
          email: '$account@gmail.com',
          walletBalance: 1000000,
        ),
      );
}

Widget buildApp({FakeAuthService? service}) => MyApp(
      session: AppSession(
        authService: service ?? FakeAuthService(acceptedPassword: '123456'),
      ),
    );

/// Cuộn tới nút trước khi bấm (nút có thể nằm ngoài khung nhìn 800x600 của test).
Future<void> tapButton(WidgetTester tester, String text) async {
  final button = find.widgetWithText(AppButton, text);
  await tester.ensureVisible(button);
  await tester.tap(button);
}

void main() {
  testWidgets('Đăng nhập thành công sẽ vào màn hình chính', (tester) async {
    await tester.pumpWidget(buildApp());

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets); // tiêu đề + nút
    expect(find.widgetWithText(AppButton, 'Đăng ký'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tapButton(tester, 'Đăng nhập');
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Xin chào, admin'), findsOneWidget);
  });

  testWidgets('Sai mật khẩu thì hiện thông báo lỗi và ở lại màn hình đăng nhập',
      (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), 'sai-mat-khau');
    await tapButton(tester, 'Đăng nhập');
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Tài khoản hoặc mật khẩu không đúng'), findsOneWidget);
  });

  testWidgets('Đăng ký: nhãn Trở về ở bên trái và quay lại màn hình đăng nhập',
      (tester) async {
    await tester.pumpWidget(buildApp());

    await tapButton(tester, 'Đăng ký');
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Xác thực mật khẩu'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Xác nhận đăng ký'), findsOneWidget);

    // Nút "Trở về" đã thay bằng label nằm bên trái.
    final backLabel = find.byType(BackLabel);
    expect(backLabel, findsOneWidget);
    final screenWidth = tester.getSize(find.byType(RegisterScreen)).width;
    expect(tester.getTopLeft(backLabel).dx, lessThan(screenWidth / 3));

    await tester.tap(find.text('Trở về'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(RegisterScreen), findsNothing);
  });

  testWidgets('Đăng ký thành công sẽ quay lại màn hình đăng nhập',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tapButton(tester, 'Đăng ký');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'nguyenvana');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.enterText(find.byType(TextFormField).at(2), '123456');
    await tapButton(tester, 'Xác nhận đăng ký');
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('Đăng ký thành công'), findsOneWidget);

    // Tài khoản vừa tạo được điền sẵn, mật khẩu để trống, chưa tự đăng nhập.
    final accountField =
        tester.widget<TextFormField>(find.byType(TextFormField).at(0));
    final passwordField =
        tester.widget<TextFormField>(find.byType(TextFormField).at(1));
    expect(accountField.controller!.text, 'nguyenvana');
    expect(passwordField.controller!.text, isEmpty);
    final session = AppScope.of(tester.element(find.byType(LoginScreen)));
    expect(session.isLoggedIn, isFalse);
  });

  testWidgets('Đăng ký: tài khoản quá dài bị chặn ở client', (tester) async {
    await tester.pumpWidget(buildApp());
    await tapButton(tester, 'Đăng ký');
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextFormField).at(0), 'a' * (kMaxAccountLength + 1));
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.enterText(find.byType(TextFormField).at(2), '123456');
    await tapButton(tester, 'Xác nhận đăng ký');
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Tài khoản tối đa $kMaxAccountLength ký tự'), findsOneWidget);
  });

  testWidgets('Tài khoản đã tồn tại sẽ hiện lỗi từ server', (tester) async {
    await tester.pumpWidget(buildApp());
    await tapButton(tester, 'Đăng ký');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.enterText(find.byType(TextFormField).at(2), '123456');
    await tapButton(tester, 'Xác nhận đăng ký');
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Tài khoản đã tồn tại'), findsOneWidget);
  });

  testWidgets('Trang chủ có nút Trang cá nhân hình vuông tròn ở góc trên bên phải', (tester) async {
    await tester.pumpWidget(buildApp());
    await _login(tester, account: 'admin', password: '123456');

    expect(find.byType(HomeScreen), findsOneWidget);

    final profileBtn = find.byTooltip('Trang cá nhân');
    expect(profileBtn, findsOneWidget);

    final screenWidth = tester.getSize(find.byType(HomeScreen)).width;
    expect(tester.getTopRight(profileBtn).dx, closeTo(screenWidth - 18, 1.5));
  });

  testWidgets('Đăng xuất từ Trang cá nhân quay về màn hình đăng nhập', (tester) async {
    await tester.pumpWidget(buildApp());
    await _login(tester, account: 'admin', password: '123456');

    // Mở Trang cá nhân từ góc trên bên phải
    await tester.tap(find.byTooltip('Trang cá nhân'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);

    // Cuộn tới nút Đăng xuất tài khoản và bấm
    final logoutBtn = find.widgetWithText(AppButton, 'Đăng xuất tài khoản');
    await tester.ensureVisible(logoutBtn);
    await tester.pumpAndSettle();
    await tester.tap(logoutBtn);
    await tester.pumpAndSettle();

    // Xác nhận trên AlertDialog
    final confirmBtn = find.widgetWithText(TextButton, 'Đăng xuất');
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Mở màn hình đổi mật khẩu từ Trang cá nhân', (tester) async {
    await tester.pumpWidget(buildApp());
    await _login(tester, account: 'admin', password: '123456');

    // Mở Trang cá nhân -> Đổi mật khẩu
    await tester.tap(find.byTooltip('Trang cá nhân'));
    await tester.pumpAndSettle();

    final changePwdMenu = find.text('Đổi mật khẩu');
    await tester.ensureVisible(changePwdMenu);
    await tester.pumpAndSettle();
    await tester.tap(changePwdMenu);
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordScreen), findsOneWidget);
    expect(find.text('Mật khẩu cũ'), findsOneWidget);
    expect(find.text('Mật khẩu mới'), findsOneWidget);
    expect(find.text('Xác thực mật khẩu'), findsOneWidget);

    // Nhãn trở lại đưa về Trang cá nhân
    await tester.tap(find.text('Trở về'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('Đổi mật khẩu: sai mật khẩu cũ sẽ hiện lỗi của server',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await _login(tester, account: 'admin', password: '123456');

    await tester.tap(find.byTooltip('Trang cá nhân'));
    await tester.pumpAndSettle();
    final changePwdMenu = find.text('Đổi mật khẩu');
    await tester.ensureVisible(changePwdMenu);
    await tester.pumpAndSettle();
    await tester.tap(changePwdMenu);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'khong-dung');
    await tester.enterText(find.byType(TextFormField).at(1), 'matkhau moi');
    await tester.enterText(find.byType(TextFormField).at(2), 'matkhau moi');
    await tapButton(tester, 'Xác nhận đổi mật khẩu');
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordScreen), findsOneWidget);
    expect(find.text('Mật khẩu cũ không đúng'), findsOneWidget);
  });

  testWidgets('Đổi mật khẩu: mật khẩu mới khác xác thực sẽ bị chặn',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await _login(tester, account: 'admin', password: '123456');

    await tester.tap(find.byTooltip('Trang cá nhân'));
    await tester.pumpAndSettle();
    final changePwdMenu = find.text('Đổi mật khẩu');
    await tester.ensureVisible(changePwdMenu);
    await tester.pumpAndSettle();
    await tester.tap(changePwdMenu);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'mat-khau-cu');
    await tester.enterText(find.byType(TextFormField).at(1), 'matkhaumoi');
    await tester.enterText(find.byType(TextFormField).at(2), 'matkhaumoi2');
    await tapButton(tester, 'Xác nhận đổi mật khẩu');
    await tester.pumpAndSettle();

    expect(find.text('Xác thực mật khẩu không khớp'), findsOneWidget);
  });

  testWidgets('Đổi mật khẩu thành công sẽ quay về trang cá nhân', (tester) async {
    await tester.pumpWidget(buildApp());
    await _login(tester, account: 'admin', password: '123456');

    await tester.tap(find.byTooltip('Trang cá nhân'));
    await tester.pumpAndSettle();
    final changePwdMenu = find.text('Đổi mật khẩu');
    await tester.ensureVisible(changePwdMenu);
    await tester.pumpAndSettle();
    await tester.tap(changePwdMenu);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'mat-khau-cu');
    await tester.enterText(find.byType(TextFormField).at(1), 'matkhau moi');
    await tester.enterText(find.byType(TextFormField).at(2), 'matkhau moi');
    await tapButton(tester, 'Xác nhận đổi mật khẩu');
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.textContaining('Đổi mật khẩu thành công'), findsOneWidget);
  });

  testWidgets('Giao diện hiển thị chuẩn xác trên kích thước màn hình iPhone 18',
      (tester) async {
    tester.view.physicalSize = const Size(kIPhone18Width, kIPhone18Height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    expect(find.byType(LoginScreen), findsOneWidget);

    await _login(tester, account: 'admin', password: '123456');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Ví điện tử DTY'), findsOneWidget);
    expect(find.text('1.000.000 đ'), findsOneWidget);

    // Kiểm tra nút Trang cá nhân ở góc trên bên phải
    final profileBtn = find.byTooltip('Trang cá nhân');
    expect(profileBtn, findsOneWidget);
  });

  testWidgets('Trang chủ: có đủ 6 nút tính năng và bấm nút Trang cá nhân mở ProfileScreen',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await _login(tester, account: 'admin', password: '123456');

    expect(find.byType(HomeScreen), findsOneWidget);

    // Kiểm tra đủ 6 tính năng (không có dấu + ở đầu)
    expect(find.text('Nạp ví'), findsOneWidget);
    expect(find.text('Nạp đt/data'), findsOneWidget);
    expect(find.text('L.sử giao dịch'), findsOneWidget);
    expect(find.text('Thanh toán hđ'), findsOneWidget);
    expect(find.text('Quỹ'), findsOneWidget);
    expect(find.text('Hũ chi tiêu'), findsOneWidget);

    // Bấm nút Trang cá nhân trên cùng bên phải
    final profileBtn = find.byTooltip('Trang cá nhân');
    expect(profileBtn, findsOneWidget);
    await tester.tap(profileBtn);
    await tester.pumpAndSettle();

    // Xác nhận đã vào màn hình ProfileScreen
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Trang chủ'), findsOneWidget); // Nút BackLabel
    expect(find.text('Mã PIN giao dịch'), findsOneWidget);
    expect(find.text('Đổi mật khẩu'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Đăng xuất tài khoản'), findsOneWidget);

    // Bấm quay lại Trang chủ
    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  test('Định dạng tiền tệ formatVnd: 0 thành 0 đ và 1000000 thành 1.000.000 đ', () {
    expect(formatVnd(0), '0 đ');
    expect(formatVnd(1000000), '1.000.000 đ');
    expect(formatVnd(50000), '50.000 đ');
    expect(formatVnd(null), '0 đ');
  });

  testWidgets('Trang chủ: Nút ẩn/hiện số dư nổi bật và hoạt động chính xác', (tester) async {
    await tester.pumpWidget(buildApp());
    await _login(tester, account: 'admin', password: '123456');

    expect(find.byType(HomeScreen), findsOneWidget);
    // Ban đầu hiển thị số dư và nút "Ẩn"
    expect(find.text('1.000.000 đ'), findsOneWidget);
    expect(find.text('Ẩn'), findsOneWidget);

    // Bấm nút Ẩn
    await tester.tap(find.text('Ẩn'));
    await tester.pumpAndSettle();

    // Số dư bị che và nút chuyển thành "Hiện"
    expect(find.text('•••••••• đ'), findsOneWidget);
    expect(find.text('Hiện'), findsOneWidget);

    // Bấm nút Hiện
    await tester.tap(find.text('Hiện'));
    await tester.pumpAndSettle();

    // Số dư hiện lại
    expect(find.text('1.000.000 đ'), findsOneWidget);
    expect(find.text('Ẩn'), findsOneWidget);
  });

  testWidgets('Trang chủ: Nút Nạp tiền cùng hàng với số dư và mở sheet Nạp tiền', (tester) async {
    await tester.pumpWidget(buildApp());
    await _login(tester, account: 'admin', password: '123456');

    expect(find.byType(HomeScreen), findsOneWidget);
    final depositBtn = find.text('Nạp tiền');
    expect(depositBtn, findsOneWidget);

    await tester.tap(depositBtn);
    await tester.pumpAndSettle();

    expect(find.text('Nạp tiền vào ví'), findsOneWidget);
  });

  testWidgets('Trang chủ: Phần Ưu đãi & Khuyến mãi có 2 phần tử mới tương tác mở Quỹ và Hũ chi tiêu', (tester) async {
    await tester.pumpWidget(buildApp());
    await _login(tester, account: 'admin', password: '123456');

    expect(find.byType(HomeScreen), findsOneWidget);

    // Kiểm tra hiển thị phần tử 1: Quỹ tiết kiệm
    final fundPromo = find.text('Lập quỹ tiết kiệm cho bản thân và gia đình');
    await tester.ensureVisible(fundPromo);
    expect(fundPromo, findsOneWidget);
    expect(find.text('Tạo quỹ cá nhân, cặp đôi, tích luỹ, ...'), findsOneWidget);

    // Kiểm tra hiển thị phần tử 2: Chi tiêu tháng theo thời gian thực và thời gian cập nhật
    final currentMonth = DateTime.now().month;
    final spendingPromo = find.text('Chi tiêu tháng $currentMonth');
    expect(spendingPromo, findsOneWidget);
    expect(find.textContaining('Cập nhật lúc'), findsOneWidget);

    // Bấm vào phần tử Quỹ -> Mở Quỹ tiết kiệm & Đầu tư sheet
    await tester.tap(fundPromo);
    await tester.pumpAndSettle();
    expect(find.text('Quỹ tiết kiệm & Đầu tư'), findsOneWidget);

    // Đóng sheet
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Bấm vào phần tử Chi tiêu tháng -> Mở Hũ chi tiêu sheet
    await tester.tap(spendingPromo);
    await tester.pumpAndSettle();
    expect(find.text('Hũ chi tiêu (6 Jars)'), findsOneWidget);
  });
}

/// Đăng nhập từ màn hình đăng nhập với tài khoản cho trước.
Future<void> _login(
  WidgetTester tester, {
  required String account,
  required String password,
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), account);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tapButton(tester, 'Đăng nhập');
  await tester.pumpAndSettle();
}