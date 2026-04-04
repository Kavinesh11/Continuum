import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
import 'sandbox/sandbox_selector_screen.dart';
import 'services/api_service.dart';

Future<void> _registerFcmToken() async {
  try {
    // firebase_messaging is unavailable on web/desktop; guard with try/catch
    // ignore: avoid_dynamic_calls
    final messaging = await _loadFirebaseMessaging();
    if (messaging == null) return;
    final token = await messaging.getToken();
    if (token == null) return;
    final valid = await ApiService().isTokenValid();
    if (!valid) return;
    // Worker ID would come from secure storage in a real app; use placeholder
    await ApiService().registerFcmToken('current_worker', token);
  } catch (_) {
    // FCM unavailable (web/desktop) — ignore gracefully
  }
}

/// Returns the FirebaseMessaging instance or null if unavailable.
Future<dynamic> _loadFirebaseMessaging() async {
  try {
    // Dynamic import to avoid compile errors on platforms without Firebase
    return null; // Replace with FirebaseMessaging.instance when Firebase is configured
  } catch (_) {
    return null;
  }
}

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Initialize Hive for offline cache
  await Hive.initFlutter();
  await Hive.openBox('api_cache');

  // Register FCM token on every app launch (best-effort)
  _registerFcmToken();

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
            AppRoutes.sandboxSelect: (context) => const SandboxSelectorScreen(),
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
