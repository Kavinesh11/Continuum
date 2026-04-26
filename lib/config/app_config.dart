import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central config — read env vars with safe fallbacks.
/// Set ADMIN_BRIDGE_URL in .env for local dev or Vercel deployment.
class AppConfig {
  AppConfig._();

  /// URL of the Next.js admin bridge (admin_dash).
  /// Local default: http://localhost:3000
  /// Vercel: set ADMIN_BRIDGE_URL=https://your-app.vercel.app in .env
  static String get adminBridgeUrl =>
      dotenv.env['ADMIN_BRIDGE_URL'] ?? 'http://localhost:3000';
}
