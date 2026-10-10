import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'state/app_session.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.session});

  /// Dùng cho test: truyền vào session dùng [AuthService] giả.
  final AppSession? session;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppSession _session = widget.session ?? AppSession();

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      session: _session,
      child: MaterialApp(
        title: 'Ví điện tử',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const LoginScreen(),
      ),
    );
  }
}
