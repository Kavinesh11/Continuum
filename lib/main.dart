import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'routes/app_routes.dart';
import 'screens/new/login.dart';
import 'screens/new/home_shell.dart';
import 'screens/new/profile.dart';
import 'screens/new/edit_profile.dart';
import 'screens/new/payments.dart';
import 'screens/new/apply_form.dart';
import 'screens/new/plan_details.dart';
import 'screens/new/policy.dart';
import 'screens/new/registration.dart';
import 'screens/new/status_tracker.dart';
import 'screens/new/oracle_engine.dart';
import 'screens/new/notifications_screen.dart';
import 'sandbox/sandbox_selector_screen.dart';
import 'sandbox/driver_provider.dart';
import 'services/api_service.dart';
import 'services/demo_backend.dart';
import 'state/demo_orchestrator.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

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
    final workerId = await ApiService().getCurrentWorkerId();
    await ApiService().registerFcmToken(workerId, token);
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

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Hive for offline cache
  await Hive.initFlutter();
  await Hive.openBox('api_cache');

  // Boot mock layer before UI renders
  DemoBackend.instance.bootstrap();
  DemoOrchestrator.instance.bootstrap();

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
        return DriverProviderRoot(
          child: MaterialApp(
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
              AppRoutes.planDetails: (context) => const PlanDetailsScreen(),
              AppRoutes.registration: (context) => const RegistrationScreen(),
              AppRoutes.editProfile: (context) => const EditProfileScreen(),
              AppRoutes.payments: (context) => const PaymentsScreen(),
              AppRoutes.oracle: (context) => const OracleEngineScreen(),
              AppRoutes.notifications: (context) => const NotificationsScreen(),
            },
          ),
        );
      },
    );
  }
}
