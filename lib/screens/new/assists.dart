import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notification_action.dart';

class AssistsScreen extends StatefulWidget {
  const AssistsScreen({Key? key}) : super(key: key);

  @override
  State<AssistsScreen> createState() => _AssistsScreenState();
}

class _AssistsScreenState extends State<AssistsScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

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
      final now = DateTime.now();
      timeLabel = _hhmm(now);
    } else {
      final parsed = DateTime.tryParse(timeRaw.toString());
      if (parsed != null) {
        timeLabel = _hhmm(parsed.toLocal());
      } else {
        timeLabel = timeRaw.toString();
      }
    }

    return {'text': text, 'isBot': isBot, 'time': timeLabel};
  }

  String _hhmm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final now = TimeOfDay.now().format(context);
    setState(() {
      _isSending = true;
      _messages.add({'text': text, 'isBot': false, 'time': now});
      _messageController.clear();
    });

    try {
      final response = await _api.sendAssistMessage(text);
      if (!mounted) return;

      final reply =
          (response['reply'] ??
                  response['response'] ??
                  response['message'] ??
                  '')
              .toString()
              .trim();
      if (reply.isNotEmpty) {
        final replyTime = TimeOfDay.now().format(context);
        setState(() {
          _messages.add({'text': reply, 'isBot': true, 'time': replyTime});
        });
      }

      setState(() {
        _isSending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
    }
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
        actions: [const NotificationAction()],
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
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
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
          _buildChatInput(context),
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
            Container(
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
