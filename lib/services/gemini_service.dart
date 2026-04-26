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
    final claimsSummary = DemoBackend.instance.getSeededClaimsSummary();
    final payoutsSummary = DemoBackend.instance.getSeededPayoutsSummary();

    final tierCoverage = switch (d.tier) {
      'Platinum' =>
        'Covered events (Platinum — all events): heavy rain/waterlogging, '
            'Swiggy & Zomato app outages, bandh/general strikes, roadblocks/road closures, '
            'cyclones/severe storms, municipal advisories, curfews/Section 144. '
            'Instant oracle auto-approval for weather & outage claims (typically under 5 minutes). '
            'Dedicated specialist review for escalated claims.',
      'Gold' =>
        'Covered events (Gold): heavy rain/waterlogging, Swiggy & Zomato app outages, '
            'bandh/general strikes, roadblocks, cyclones, municipal advisories. '
            'Priority review within 4–12 hours.',
      _ =>
        'Covered events (Silver): heavy rain/waterlogging, Swiggy app outages, '
            'network failures. Standard review within 24–48 hours. '
            'Bandh/cyclone coverage requires Gold or Platinum tier.',
    };

    final earningsSummary =
        '₹${d.weeklyEarnings.toStringAsFixed(0)} this week '
        '(${d.orderHistory.where((o) => o.status == 'completed').length}/${d.weeklyOrderCount} orders completed, '
        '${(d.completionRate * 100).toStringAsFixed(0)}% completion rate)';

    return '''You are Continuum's AI claims assistant for ${d.fullName} (Partner ID: ${d.partnerId}), a ${d.tier} tier ${d.platform} delivery partner in ${d.city}, zone ${d.zone}. Member since ${d.memberSince}.

POLICY: ${d.tier} Shield Plan — ₹${d.totalProtected.toStringAsFixed(0)} total protection, ₹${d.weeklyPremium.toStringAsFixed(0)}/week premium, next renewal ${d.nextRenewal}. Claims approved to date: ${d.claimsApproved}. Coverage status: ${d.coverageStatus}.

EARNINGS: $earningsSummary

CLAIM HISTORY:
$claimsSummary

RECENT PAYOUTS:
$payoutsSummary

COVERAGE: $tierCoverage NOT covered: vehicle breakdowns outside GPS-verified disruption zones, orders cancelled by the partner, events outside registered zone, pre-existing conditions.

INSTRUCTIONS: Be concise (2–3 sentences max), empathetic, and conversational. Address the partner by first name (${d.fullName.split(' ').first}). Use ₹ for amounts. When asked about a specific claim, refer to the claim history above. When asked about payouts, refer to recent payouts above. Help with coverage questions, claim filing, status checks, and payout queries.''';
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
          final parts = candidates.first['content']?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return (parts.first['text'] as String? ?? '').trim();
          }
        }
      }
    } catch (_) {}
    return _mockReply(userMessage);
  }

  String _mockReply(String msg) {
    final d = DemoBackend.instance.activeDriver;
    final lower = msg.toLowerCase();
    final name = d.fullName.split(' ').first;
    final claims = DemoBackend.instance.getSeededClaimsSummary();
    final pendingClaims = claims.split('\n').where((l) => l.contains('In Review') || l.contains('Pending'));

    if (lower.contains('flood') || lower.contains('severe weather') || lower.contains('rain')) {
      final weatherClaim = claims.split('\n').firstWhere(
        (l) => l.toLowerCase().contains('weather') || l.toLowerCase().contains('flood') || l.toLowerCase().contains('rain'),
        orElse: () => '',
      );
      if (weatherClaim.isNotEmpty) {
        return 'Hi $name! I can see your weather-related claim: $weatherClaim. Let me know if you need more details.';
      }
      return 'Hi $name! Severe weather and flooding are fully covered under your ${d.tier} plan. You can file a claim from the Apply Claim screen on your dashboard.';
    }

    if (lower.contains('outage') || lower.contains('app')) {
      final outageClaim = claims.split('\n').firstWhere(
        (l) => l.toLowerCase().contains('outage'),
        orElse: () => '',
      );
      if (outageClaim.isNotEmpty) {
        return 'Hi $name! Your platform outage claim: $outageClaim. Oracle is cross-referencing incident logs — this typically resolves within a few hours.';
      }
      return 'App outages on ${d.platform} are covered under your plan. The oracle network automatically cross-checks platform incident logs within minutes.';
    }

    if (lower.contains('reject') || lower.contains('denied') || lower.contains('breakdown')) {
      final rejectedClaim = claims.split('\n').firstWhere(
        (l) => l.contains('Rejected'),
        orElse: () => '',
      );
      if (rejectedClaim.isNotEmpty) {
        return 'Hi $name, I see a rejected claim: $rejectedClaim. Vehicle breakdowns are only covered when GPS confirms the partner was in an oracle-verified disruption zone at the time.';
      }
      return 'Vehicle breakdowns are not covered unless GPS data confirms you were inside an active disruption zone. Check your zone status on the dashboard.';
    }

    if (lower.contains('claim') || lower.contains('status') || lower.contains('review') || lower.contains('pending')) {
      final pendingList = pendingClaims.toList();
      if (pendingList.isNotEmpty) {
        return 'Hi $name! You have ${pendingList.length} claim(s) currently in review: ${pendingList.first}. Updates arrive as notifications.';
      }
      return 'Hi $name! All your recent claims have been processed. Tap "Apply Claim" on the dashboard to submit a new one — it only takes a minute.';
    }

    if (lower.contains('payout') || lower.contains('upi') || lower.contains('money') || lower.contains('credit')) {
      final payouts = DemoBackend.instance.getSeededPayoutsSummary();
      final firstPayout = payouts.split('\n').first;
      return 'Your most recent payout: $firstPayout. Approved payouts reach your UPI within 5 minutes via eNACH on PayU.';
    }

    if (lower.contains('premium') || lower.contains('renew') || lower.contains('week')) {
      return 'Your ${d.tier} Shield premium is ₹${d.weeklyPremium.toStringAsFixed(0)}/week, next debited on ${d.nextRenewal}. Auto-debit via eNACH — no action needed from you.';
    }

    if (lower.contains('coverage') || lower.contains('cover') || lower.contains('covered') || lower.contains('protect')) {
      return 'Your ${d.tier} Shield plan covers ₹${d.totalProtected.toStringAsFixed(0)} total. ${d.tier == 'Silver' ? 'Covers rain, outages, and network failures.' : d.tier == 'Gold' ? 'Covers rain, outages, bandh, roadblocks, and cyclones.' : 'Covers all events including cyclones, bandh, curfews, and municipal advisories — with instant oracle approval.'}';
    }

    if (lower.contains('bandh') || lower.contains('strike') || lower.contains('hartaal')) {
      if (d.tier == 'Silver') {
        return 'Hi $name, bandh/general strike coverage is available on Gold and Platinum plans. Consider upgrading your plan for full protection during hartaals and strikes.';
      }
      return 'Bandh and general strike coverage is active on your ${d.tier} plan, $name. The oracle network detects declared strikes automatically — no manual filing needed.';
    }

    if (lower.contains('zone') || lower.contains('area') || lower.contains('location')) {
      return 'You\'re registered in ${d.zone}, $name. Claims must originate from within your registered zone. GPS verification happens automatically during oracle review.';
    }

    if (lower.contains('earn') || lower.contains('order') || lower.contains('week')) {
      return 'This week you\'ve earned ₹${d.weeklyEarnings.toStringAsFixed(0)} across ${d.orderHistory.where((o) => o.status == 'completed').length} completed orders, $name. Your completion rate is ${(d.completionRate * 100).toStringAsFixed(0)}%.';
    }

    return 'I\'m here to help with your coverage and claims, $name. Ask me about your active claims, payouts, policy details, or how to file a new claim.';
  }
}
