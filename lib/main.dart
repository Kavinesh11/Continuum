import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'routes/app_routes.dart';
import 'screens/login.dart';
import 'screens/home_shell.dart';
import 'screens/profile.dart';
import 'screens/edit_profile.dart';
import 'screens/payments.dart';
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

class ContinuumApp extends StatefulWidget {
  const ContinuumApp({Key? key}) : super(key: key);

  /// Access the ThemeProvider from anywhere
  static ThemeProvider themeProviderOf(BuildContext context) {
    return context.findAncestorStateOfType<_ContinuumAppState>()!.themeProvider;
  }

  @override
  State<ContinuumApp> createState() => _ContinuumAppState();
}

class _ContinuumAppState extends State<ContinuumApp> {
  final ThemeProvider themeProvider = ThemeProvider();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, _) {
        return MaterialApp(
          title: 'Continuum',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          initialRoute: AppRoutes.login,
          routes: {
            AppRoutes.login: (context) => const LoginScreen(),
            AppRoutes.home: (context) => const HomeShell(),
            AppRoutes.apply: (context) => const ApplyFormScreen(),
            AppRoutes.claimStatus: (context) => const StatusTrackerScreen(),
            AppRoutes.profile: (context) => const ProfileScreen(),
            AppRoutes.policy: (context) => const PolicyScreen(),
            AppRoutes.editProfile: (context) => const EditProfileScreen(),
            AppRoutes.payments: (context) => const PaymentsScreen(),
          },
        );
      },
    );
  }
}
