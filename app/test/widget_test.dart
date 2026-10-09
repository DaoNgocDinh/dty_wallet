// Widget test cho luồng đăng nhập / đăng ký (dùng AuthService giả, không gọi API thật).

import 'package:app/main.dart';
import 'package:app/screens/home_screen.dart';
import 'package:app/screens/login_screen.dart';
import 'package:app/screens/register_screen.dart';
import 'package:app/screens/test_login_screen.dart';
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

  testWidgets('Màn hình test đăng nhập gọi API và hiện kết quả', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TestLoginScreen(
          authService: FakeAuthService(acceptedPassword: '123456'),
        ),
      ),
    );

    expect(find.byType(TestLoginScreen), findsOneWidget);
    // Tài khoản/mật khẩu được điền sẵn (admin / 123456) để test nhanh.
    expect(find.widgetWithText(AppButton, 'Test đăng nhập'), findsOneWidget);

    await tapButton(tester, 'Test đăng nhập');
    await tester.pumpAndSettle();

    expect(find.text('KẾT QUẢ: THÀNH CÔNG'), findsOneWidget);
    expect(find.text('admin@gmail.com'), findsOneWidget);

    // Token nhận được dùng để gọi API cần xác thực.
    await tapButton(tester, 'Kiểm tra token (GET /api/wallet)');
    await tester.pumpAndSettle();
    expect(find.textContaining('Token hợp lệ'), findsOneWidget);
  });

  testWidgets('Test đăng nhập sai mật khẩu sẽ hiện lỗi', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TestLoginScreen(
          authService: FakeAuthService(acceptedPassword: 'mat-khau-khac'),
        ),
      ),
    );

    await tapButton(tester, 'Test đăng nhập');
    await tester.pumpAndSettle();

    expect(find.text('KẾT QUẢ: THẤT BẠI'), findsOneWidget);
    expect(find.text('Tài khoản hoặc mật khẩu không đúng'), findsOneWidget);
  });

  testWidgets('Mở được màn hình test từ màn hình đăng nhập', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byTooltip('Màn hình test đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.byType(TestLoginScreen), findsOneWidget);
  });
}