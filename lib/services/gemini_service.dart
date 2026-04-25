import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'demo_backend.dart';

class GeminiService {
  static const _model = 'gemini-2.0-flash';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static String _systemContext() {
    final d = DemoBackend.instance.activeDriver;
    return "You are Continuum's AI Claims Assistant helping ${d.fullName}, "
        "a ${d.tier} tier ${d.platform} delivery partner in ${d.city}, zone ${d.zone}. "
        "Weekly premium: ₹${d.weeklyPremium.toStringAsFixed(0)}. "
        "Claims approved to date: ${d.claimsApproved}. "
        "Covered events: heavy rain/waterlogging, app outages (Swiggy/Zomato), "
        "bandh/general strikes, roadblocks, cyclones, municipal advisories, curfews. "
        "NOT covered: vehicle breakdowns outside disruption zones (GPS-verified). "
        "Be concise (2–3 sentences max), empathetic, and use ₹ for amounts. "
        "Address the partner by first name. Help with coverage questions, claim filing, and status checks.";
  }

  Future<String> chat(
    String userMessage,
    List<Map<String, String>> history,
  ) async {
    if (_apiKey.isEmpty) return _mockReply(userMessage);

    final contents = [
      for (final m in history)
        {
          'role': m['role'],
          'parts': [
            {'text': m['content']},
          ],
        },
      {
        'role': 'user',
        'parts': [
          {'text': userMessage},
        ],
      },
    ];

    try {
      final resp = await http
          .post(
            Uri.parse('$_baseUrl?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'system_instruction': {
                'parts': [
                  {'text': _systemContext()},
                ],
              },
              'contents': contents,
              'generationConfig': {
                'temperature': 0.7,
                'maxOutputTokens': 350,
              },
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts =
              candidates.first['content']?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return (parts.first['text'] as String? ?? '').trim();
          }
        }
      }
    } catch (_) {}
    return _mockReply(userMessage);
  }

  String _mockReply(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('claim')) {
      return "You can file a new claim from the home screen. I'll guide you through the process — it only takes a minute.";
    }
    if (lower.contains('coverage') || lower.contains('cover')) {
      return 'Your plan covers rain, app outages, bandh, cyclones, and municipal advisories in your zone. Vehicle breakdowns require GPS verification.';
    }
    if (lower.contains('payout') || lower.contains('amount')) {
      return 'Payouts range from ₹180–₹450 depending on the disruption type and your coverage tier. Approved amounts are credited within minutes.';
    }
    if (lower.contains('bandh') || lower.contains('strike')) {
      return 'Bandh coverage is active for declared general strikes in your zone. The oracle network detects it automatically and triggers your payout.';
    }
    if (lower.contains('status') || lower.contains('track')) {
      return 'You can track your claim status from the home screen. I\'ll show you the current stage and expected payout.';
    }
    return "I'm here to help with your coverage and claims. What would you like to know?";
  }
}
