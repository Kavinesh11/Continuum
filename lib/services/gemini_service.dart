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

PROJECT FAQ:
- What is Continuum? India's first parametric income-protection platform for Swiggy & Zomato delivery partners. Oracle network auto-detects disruptions and credits UPI payouts — often within minutes of the event, no forms needed.
- How does parametric insurance work? Pre-defined triggers (rain, bandh, outage) → oracle detects event automatically → payout credited. Partners never need to prove individual loss — the event itself triggers compensation.
- What is the oracle network? Five decentralized data sources (IMD rainfall API, municipal feeds, traffic density index, Swiggy/Zomato incident logs, GPS zone data). When 3 of 5 sources confirm a disruption, the oracle auto-approves all eligible partners in the zone.
- How long do payouts take? Auto-approved (Platinum): under 5 minutes to UPI. Priority review (Gold): 4–12 hours. Standard review (Silver): 24–48 hours. Manual submissions always start as In Progress and auto-advance through review.
- How is premium calculated? Base rate set by tier; dynamically adjusted each week by zone risk, order completion rate, waterlogging incidents, platform uptime, and traffic density. View the ML recalculation on the Policy screen.
- How does auto-debit work? Weekly premium is auto-debited every Monday via eNACH mandate (PayU). No action needed. View debit history in the Payments section.
- How do I upgrade my plan? Contact Continuum support or upgrade from the Policy screen. Changes take effect on the next billing cycle.
- What if my claim is rejected? File an appeal within 7 days with supporting evidence (GPS log, photos). Specialists review escalated cases within 24 hours.
- What events are covered? See COVERAGE section above — varies by tier. Platinum covers all 7 event types; Gold covers 6; Silver covers 3.

INSTRUCTIONS: Be concise (2–4 sentences), empathetic, and conversational. Address the partner by first name (${d.fullName.split(' ').first}). Use ₹ for amounts. When asked about a specific claim, refer to the claim history above. When asked about payouts, refer to recent payouts above. For FAQ questions, answer from the PROJECT FAQ section. Help with coverage questions, claim filing, status checks, payout queries, and general product questions.''';
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

    // ── FAQ quick-reply overrides — checked first to avoid false positives ──────

    if (lower.contains('how long') || lower.contains('payout time') || lower.contains('when will i get') || lower.contains('how fast')) {
      return 'Auto-approved payouts on your ${d.tier} plan reach your UPI in under 5 minutes, $name. '
          'Manual claims in review: Gold priority is 4–12 hours, Silver is 24–48 hours. '
          'You get a push notification the moment funds are credited.';
    }

    if ((lower.contains('file') && lower.contains('claim')) || lower.contains('how do i claim') || lower.contains('how to claim') || lower.contains('new claim') || lower.contains('submit a claim')) {
      return 'To file a claim, tap "Apply Claim" on your dashboard, $name. '
          'Pick the event type, add the date and a brief description — photos are optional. '
          'Most weather and outage events are auto-detected by the oracle before you even file, so check your notifications first.';
    }

    if (lower.contains('what is continuum') || lower.contains('about continuum') || lower.contains('how does continuum') || lower.contains('what does continuum')) {
      return 'Continuum is India\'s first parametric income-protection platform for Swiggy & Zomato delivery partners. '
          'When a disruption event is detected — rain, bandh, outage — the oracle network auto-credits your UPI account, '
          'often within minutes. No forms, no waiting, no guesswork.';
    }

    if (lower.contains('how does oracle') || lower.contains('oracle work') || lower.contains('oracle network')) {
      return 'The oracle network combines 5 data feeds: IMD rainfall API, municipal disruption notices, '
          'traffic density index, Swiggy/Zomato platform incident logs, and GPS zone data. '
          'When 3-of-5 sources agree a disruption occurred in your zone, consensus is reached and payouts fire — '
          'no human approval needed for standard events. ML model accuracy: 94.7%.';
    }

    if (lower.contains('silver vs') || lower.contains('vs gold') || lower.contains('vs platinum') || lower.contains('plan difference') || lower.contains('which plan')) {
      return 'Silver (₹49/wk): rain, outages, network failures — 24–48h review.\n'
          'Gold (₹99/wk): adds bandh, cyclone, Zomato outage, roadblocks — 4–12h priority review.\n'
          'Platinum (₹199/wk): all 7 event types including curfews and municipal advisories — instant oracle auto-approval under 5 min.\n'
          'You\'re currently on ${d.tier} tier.';
    }

    if (lower.contains('auto-debit') || lower.contains('auto debit') || lower.contains('enach') || lower.contains('how does auto') || lower.contains('debit work')) {
      return 'Your ₹${d.weeklyPremium.toStringAsFixed(0)}/week premium is auto-debited every Monday via eNACH mandate on PayU, $name. '
          'No action needed — it happens automatically. '
          'If a debit fails, you get a 7-day grace period before coverage pauses. '
          'View debit history in the Payments section.';
    }

    // ── General keyword handlers ─────────────────────────────────────────────────

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

    if (lower.contains('what is continuum') || lower.contains('about continuum') || lower.contains('how does continuum') || lower.contains('what does continuum')) {
      return 'Continuum is India\'s first parametric income-protection platform for Swiggy & Zomato delivery partners. When a disruption event is detected — rain, bandh, outage — the oracle network auto-credits your UPI account, often within minutes. No forms, no waiting, no guesswork.';
    }

    if (lower.contains('parametric') || lower.contains('how does it work') || lower.contains('how it works')) {
      return 'Parametric insurance pays out when a pre-defined event occurs — not based on your individual loss. When 3 of 5 oracle sources confirm a disruption in your zone, every eligible partner in that zone gets credited automatically. No proof required, $name.';
    }

    if (lower.contains('oracle') || lower.contains('oracle network') || lower.contains('how does oracle')) {
      return 'The oracle network combines 5 data feeds: IMD rainfall API, municipal disruption notices, traffic density index, Swiggy/Zomato platform incident logs, and GPS zone data. When 3 of 5 agree a disruption occurred, consensus is reached and payouts fire automatically — no human approval needed for standard events.';
    }

    if (lower.contains('how long') || lower.contains('payout time') || lower.contains('when will i get') || lower.contains('how fast')) {
      return 'Auto-approved payouts on your ${d.tier} plan reach your UPI in under 5 minutes. Manual claims start In Progress and advance through review — Gold priority review is 4–12 hours, Silver is 24–48 hours. You\'ll get a notification the moment funds are credited.';
    }

    if (lower.contains('enach') || lower.contains('mandate') || lower.contains('auto debit') || lower.contains('auto-debit') || lower.contains('debit')) {
      return 'Your ₹${d.weeklyPremium.toStringAsFixed(0)}/week premium is auto-debited every Monday via eNACH mandate on PayU, $name. No action needed — you can see debit history in the Payments section.';
    }

    if (lower.contains('upgrade') || lower.contains('switch plan') || lower.contains('change plan') || lower.contains('higher tier')) {
      return 'To upgrade from ${d.tier}, contact Continuum support or use the Policy screen. Upgrades take effect on your next billing cycle. Platinum gives you instant oracle auto-approval and all 7 covered event types.';
    }

    if (lower.contains('cancel') || lower.contains('opt out') || lower.contains('stop coverage') || lower.contains('unsubscribe')) {
      return 'You can cancel your plan from the Policy screen, $name. A 7-day notice period applies. Any approved claims before cancellation will still be paid out.';
    }

    if (lower.contains('appeal') || lower.contains('dispute') || lower.contains('escalate')) {
      return 'If a claim is rejected, you can appeal within 7 days by submitting additional evidence — GPS log, photos, or delivery platform records. Our specialist team reviews escalated cases within 24 hours, $name.';
    }

    if (lower.contains('tier') || lower.contains('silver') || lower.contains('gold') || lower.contains('platinum') || lower.contains('plan difference') || lower.contains('which plan')) {
      return 'Silver covers rain, outages, and network failures (24–48h review). Gold adds bandh, roadblocks, and cyclones with priority review (4–12h). Platinum covers all 7 event types including curfews and municipal advisories — with instant oracle auto-approval, typically under 5 minutes.';
    }

    if (lower.contains('file') || lower.contains('submit') || lower.contains('apply') || lower.contains('new claim') || lower.contains('how to claim')) {
      return 'To file a claim, tap "Apply Claim" on your dashboard, $name. Select the event type, add the date and a brief description — photos are optional. Most covered events are auto-detected by oracle before you even file, so check your notifications first.';
    }

    return 'I\'m not sure I caught that, $name. Did you mean to ask about:\n'
        '• Your recent claim or payout?\n'
        '• Your ₹${d.weeklyPremium.toStringAsFixed(0)}/week premium?\n'
        '• How to file a new claim?';
  }
}
