import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/login_screen.dart';
import '../core/widgets/app_shell.dart';
import '../core/widgets/app_snackbar.dart';

class SalesErpApp extends StatelessWidget {
  const SalesErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: appScaffoldMessengerKey,
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Warehouse Management',
      theme: AppTheme.light(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
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
