import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ví điện tử',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Builder(
        // Builder để context nằm bên dưới Navigator, khi đó mới điều hướng được.
        builder: (context) => LoginScreen(
          onLoginSuccess: (account) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => HomeScreen(account: account),
              ),
            );
          },
        ),
      ),
    );
  }
}