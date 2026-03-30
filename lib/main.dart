import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'routes/app_routes.dart';
import 'screens/login.dart';
import 'screens/home_shell.dart';
import 'screens/profile.dart';
import 'screens/apply_form.dart';
import 'screens/policy.dart';
import 'screens/status_tracker.dart';

void main() {
  usePathUrlStrategy();
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
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.home: (context) => const HomeShell(),
        AppRoutes.apply: (context) => const ApplyFormScreen(),
        AppRoutes.claimStatus: (context) => const StatusTrackerScreen(),
        AppRoutes.profile: (context) => const ProfileScreen(),
        AppRoutes.policy: (context) => const PolicyScreen(),
      },
    );
  }
}
