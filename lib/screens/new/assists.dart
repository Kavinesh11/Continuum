import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/demo_backend.dart';
import '../../services/gemini_service.dart';
import '../../state/demo_orchestrator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notification_action.dart';

class AssistsScreen extends StatefulWidget {
  const AssistsScreen({Key? key}) : super(key: key);

  @override
  State<AssistsScreen> createState() => _AssistsScreenState();
}

class _AssistsScreenState extends State<AssistsScreen> {
  final ApiService _api = ApiService();
  final GeminiService _gemini = GeminiService();
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final List<Map<String, String>> _chatHistory = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isTyping = false;
  String? _error;

  // ── Shared easter egg counter for bot avatar taps ──────────────────────────
  int _eggCount = 0;
  DateTime? _eggFirst;

  void _onBotAvatarTap() {
    final now = DateTime.now();
    if (_eggFirst == null || now.difference(_eggFirst!) > const Duration(seconds: 3)) {
      _eggCount = 1;
      _eggFirst = now;
    } else {
      _eggCount++;
    }
    if (_eggCount >= 4) {
      _eggCount = 0;
      _eggFirst = null;
      DemoOrchestrator.instance.autoClaimAndPayout();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await _api.getAssistMessages();
      if (!mounted) return;

      _messages
        ..clear()
        ..addAll(items.map(_mapMessage));

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Unable to load assist messages';
      });
    }
  }

  Map<String, dynamic> _mapMessage(Map<String, dynamic> raw) {
    final role = (raw['role'] ?? raw['sender'] ?? 'assistant').toString();
    final isBot = role != 'user';
    final text = (raw['text'] ?? raw['message'] ?? raw['content'] ?? '')
        .toString();
    final timeRaw = raw['time'] ?? raw['created_at'] ?? raw['timestamp'];

    String timeLabel;
    if (timeRaw == null) {
      timeLabel = _hhmm(DateTime.now());
    } else {
      final parsed = DateTime.tryParse(timeRaw.toString());
      timeLabel = parsed != null ? _hhmm(parsed.toLocal()) : timeRaw.toString();
    }

    return {'text': text, 'isBot': isBot, 'time': timeLabel};
  }

  String _hhmm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _sendQuickMessage(String text) {
    if (_isSending || _isTyping) return;
    _messageController.text = text;
    _sendMessage();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending || _isTyping) return;

    final now = _hhmm(DateTime.now());
    setState(() {
      _isSending = true;
      _isTyping = true;
      _messages.add({'text': text, 'isBot': false, 'time': now});
      _messageController.clear();
    });

    final reply = await _gemini.chat(text, List.from(_chatHistory));

    _chatHistory.add({'role': 'user', 'content': text});
    _chatHistory.add({'role': 'model', 'content': reply});

    if (!mounted) return;
    setState(() {
      _isSending = false;
      _isTyping = false;
      _messages.add({'text': reply, 'isBot': true, 'time': _hhmm(DateTime.now())});
    });
  }

  void _showEscalationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _EscalationSheet(
        messages: List.from(_messages),
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CONTINUUM'),
        leading: GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/profile'),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.accentGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showEscalationSheet,
            icon: const Icon(Icons.headset_mic_rounded),
            color: AppTheme.primary,
            tooltip: 'Get more help',
          ),
          const NotificationAction(),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error ?? 'No assist messages yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondaryOf(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isTyping && index == _messages.length) {
                        return _buildTypingIndicator(context);
                      }
                      final msg = _messages[index];
                      return _buildMessageBubble(
                        context: context,
                        text: msg['text'] as String,
                        isBot: msg['isBot'] as bool,
                        time: msg['time'] as String,
                      );
                    },
                  ),
          ),
          _buildQuickReplies(context),
          _buildChatInput(context),
        ],
      ),
    );
  }

  static const _defaultReplies = [
    'What is Continuum?',
    'How does oracle work?',
    'How long do payouts take?',
    'Silver vs Gold vs Platinum?',
    'How do I file a claim?',
    'How does auto-debit work?',
  ];

  List<String> _buildContextualQuickReplies() {
    final driver = DemoBackend.instance.activeDriver;
    final replies = <String>[];

    // Priority contextual suggestions
    final claims = _messages
        .where((m) => m['isBot'] == true)
        .map((m) => m['text'] as String)
        .join(' ')
        .toLowerCase();

    final hasPendingClaim = claims.contains('in review') || claims.contains('pending');
    final hadRecentPayout = claims.contains('payout') || claims.contains('credited');
    final isSilver = driver.tier == 'Silver';

    if (hasPendingClaim) {
      replies.add('What\'s happening with my claim?');
    }
    if (hadRecentPayout) {
      replies.add('Explain my recent auto-payout');
    }
    if (isSilver) {
      replies.add('Should I upgrade to Gold?');
    }

    // Fill remaining with defaults
    for (final r in _defaultReplies) {
      if (!replies.contains(r) && replies.length < 5) {
        replies.add(r);
      }
    }
    return replies;
  }

  // Detect if bot response suggests a navigation action
  String? _detectActionRoute(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('apply claim') || lower.contains('tap "apply claim"') ||
        lower.contains('file a claim') || lower.contains('submit a claim')) {
      return AppRoutes.apply;
    }
    if (lower.contains('policy screen') || lower.contains('upgrade') ||
        lower.contains('switch plan') || lower.contains('plan details')) {
      return AppRoutes.planDetails;
    }
    if (lower.contains('payments section') || lower.contains('debit history') ||
        lower.contains('view in payment')) {
      return AppRoutes.payments;
    }
    if (lower.contains('oracle') && (lower.contains('screen') || lower.contains('view'))) {
      return AppRoutes.oracle;
    }
    return null;
  }

  String _actionLabel(String route) {
    return switch (route) {
      AppRoutes.apply => 'Open claim form',
      AppRoutes.planDetails => 'View plans',
      AppRoutes.payments => 'See payments',
      AppRoutes.oracle => 'View oracle',
      _ => 'Go →',
    };
  }

  Widget _buildQuickReplies(BuildContext context) {
    if (_isTyping || _isSending) return const SizedBox.shrink();
    final replies = _buildContextualQuickReplies();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: replies.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) => GestureDetector(
            onTap: () => _sendQuickMessage(replies[i]),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
              ),
              child: Text(
                replies[i],
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActionChips(BuildContext context, String text) {
    final route = _detectActionRoute(text);
    if (route == null) return [];
    return [
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () => Navigator.pushNamed(context, route),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                _actionLabel(route),
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildTypingIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: AppTheme.primaryGlow(0.2),
            ),
            child: const Icon(Icons.smart_toy_rounded, size: 16, color: Colors.white),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.cardOf(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: AppTheme.softShadowOf(context),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  _BouncingDot(delay: Duration(milliseconds: i * 160)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required BuildContext context,
    required String text,
    required bool isBot,
    required String time,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: isBot
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isBot) ...[
            GestureDetector(
              onTap: _onBotAvatarTap,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.primaryGlow(0.2),
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isBot
                        ? AppTheme.cardOf(context)
                        : AppTheme.primary.withOpacity(0.9),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isBot ? 0 : 16),
                      bottomRight: Radius.circular(isBot ? 16 : 0),
                    ),
                    boxShadow: AppTheme.softShadowOf(context),
                  ),
                  child: Column(
                    crossAxisAlignment: isBot
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 14,
                          color: isBot
                              ? AppTheme.textPrimaryOf(context)
                              : Colors.white,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          color: isBot
                              ? AppTheme.textHintOf(context)
                              : Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // Inline action chip for bot messages that suggest navigation
                if (isBot) ..._buildActionChips(context, text),
              ],
            ),
          ),
          if (!isBot) const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildChatInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.cardOf(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.dividerOf(context)),
              ),
              child: TextField(
                controller: _messageController,
                style: TextStyle(
                  color: AppTheme.textPrimaryOf(context),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask Assist anything...',
                  hintStyle: TextStyle(color: AppTheme.textHintOf(context)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              shape: BoxShape.circle,
              boxShadow: AppTheme.primaryGlow(0.2),
            ),
            child: IconButton(
              onPressed: _isLoading ? null : _sendMessage,
              icon: const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Escalation / help sheet ────────────────────────────────────────────────────

class _EscalationSheet extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final VoidCallback onClose;
  const _EscalationSheet({required this.messages, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadowOf(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.headset_mic_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Get more help',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _EscalationOption(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Chat transcript',
            subtitle: '${messages.length} messages in this session',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Transcript saved to your email.'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _EscalationOption(
            icon: Icons.email_outlined,
            title: 'Email support',
            subtitle: 'support@continuum.in · response within 24h',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Opening email...'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _EscalationOption(
            icon: Icons.chat_rounded,
            title: 'WhatsApp',
            subtitle: '+91 98765 43210 · typically replies in 2h',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Opening WhatsApp...'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _EscalationOption(
            icon: Icons.flag_outlined,
            title: 'Report an issue',
            subtitle: 'Incorrect payout, claim error, fraud concerns',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Report form coming soon.'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onClose,
              child: Text('Close',
                  style: TextStyle(color: AppTheme.textSecondaryOf(context))),
            ),
          ),
        ],
      ),
    );
  }
}

class _EscalationOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _EscalationOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.04),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.dividerOf(context)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryOf(context),
                  )),
                  Text(subtitle, style: TextStyle(
                    fontSize: 11, color: AppTheme.textSecondaryOf(context),
                  )),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.textHintOf(context), size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Typing indicator dot ──────────────────────────────────────────────────────

class _BouncingDot extends StatefulWidget {
  final Duration delay;
  const _BouncingDot({required this.delay});

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: AppTheme.textHintOf(context),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
