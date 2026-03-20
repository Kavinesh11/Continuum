import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login.dart';
import 'screens/dashboard.dart';
import 'screens/claims.dart';
import 'screens/assists.dart';
import 'screens/profile.dart';
import 'screens/apply_form.dart';
import 'screens/status_tracker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const ContinuumApp());
}

class ContinuumApp extends StatelessWidget {
  const ContinuumApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Continuum',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/claims': (context) => const ClaimsScreen(),
        '/assists': (context) => const AssistsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/apply': (context) => const ApplyFormScreen(),
        '/tracker': (context) => const StatusTrackerScreen(),
      },
      onInitialRoute: (String initialRoute) {
         // Placeholder
      },
    );
  }
}
