// Widget test cho luồng đăng nhập / đăng ký.

import 'package:app/main.dart';
import 'package:app/screens/home_screen.dart';
import 'package:app/screens/login_screen.dart';
import 'package:app/screens/register_screen.dart';
import 'package:app/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Đăng nhập thành công sẽ vào màn hình chính', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets); // tiêu đề + nút
    expect(find.text('Đăng ký'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'nguyenvana',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'matkhau123');

    await tester.tap(find.widgetWithText(AppButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Nút Đăng ký mở màn hình đăng ký và Trở về quay lại',
      (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.widgetWithText(AppButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Xác thực mật khẩu'), findsOneWidget);
    expect(find.text('Xác nhận đăng ký'), findsOneWidget);
    expect(find.text('Trở về'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppButton, 'Trở về'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(RegisterScreen), findsNothing);
  });
}