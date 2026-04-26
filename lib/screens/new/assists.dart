import 'package:flutter/material.dart';
import '../../services/api_service.dart';
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

  void _showCallSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _VoiceAgentSheet(
        driverName: 'Partner',
        onEnd: () => Navigator.pop(ctx),
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
            onPressed: _showCallSheet,
            icon: const Icon(Icons.phone_rounded),
            color: AppTheme.primary,
            tooltip: 'Voice Agent',
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

  static const _quickReplies = [
    'What is Continuum?',
    'How does oracle work?',
    'How long do payouts take?',
    'Silver vs Gold vs Platinum?',
    'How do I file a claim?',
    'How does auto-debit work?',
  ];

  Widget _buildQuickReplies(BuildContext context) {
    if (_isTyping || _isSending) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => _sendQuickMessage(_quickReplies[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
            ),
            child: Text(
              _quickReplies[i],
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
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
            child: Container(
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

// ── Voice agent call sheet ─────────────────────────────────────────────────────

class _VoiceAgentSheet extends StatefulWidget {
  final String driverName;
  final VoidCallback onEnd;
  const _VoiceAgentSheet({required this.driverName, required this.onEnd});

  @override
  State<_VoiceAgentSheet> createState() => _VoiceAgentSheetState();
}

class _VoiceAgentSheetState extends State<_VoiceAgentSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadowOf(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dividerOf(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.accentGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.2 + _pulse.value * 0.25),
                    blurRadius: 20 + _pulse.value * 20,
                    spreadRadius: _pulse.value * 6,
                  ),
                ],
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Voice Agent',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Connecting you to a live voice agent...',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Continuum Assist • Secured',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.successGreen,
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: widget.onEnd,
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppTheme.dangerRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.call_end_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'End Call',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ],
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
