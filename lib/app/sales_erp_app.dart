import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/login_screen.dart';
import '../core/widgets/app_shell.dart';

class SalesErpApp extends StatelessWidget {
  const SalesErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sales ERP',
      theme: AppTheme.light(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snapshot.data;
          final isSignedIn = user != null;

          if (!isSignedIn) {
            return const LoginScreen();
          }

          return DesktopEntry(
            onLogout: () {
              FirebaseAuth.instance.signOut();
            },
          );
        },
      ),
    );
  }
}
