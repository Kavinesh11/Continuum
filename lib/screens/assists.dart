import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';

class AssistsScreen extends StatefulWidget {
  const AssistsScreen({Key? key}) : super(key: key);

  @override
  State<AssistsScreen> createState() => _AssistsScreenState();
}

class _AssistsScreenState extends State<AssistsScreen> {
  final TextEditingController _messageController = TextEditingController();

  final List<Map<String, dynamic>> _messages = [
    {
      'text': 'Hi there! I am Continuum Assist. How can I help you today?',
      'isBot': true,
      'time': '10:00 AM',
    },
    {
      'text': 'What is my current expected payout?',
      'isBot': false,
      'time': '10:01 AM',
    },
    {
      'text': 'Based on your latest shifts, your expected payout is ₹2,850. Would you like to view detailed earnings?',
      'isBot': true,
      'time': '10:01 AM',
    },
    {
      'text': 'என் பிரீமியம் திட்டம் என்ன?',
      'isBot': false,
      'time': '10:02 AM',
    },
    {
      'text': 'உங்கள் பிரீமியம் திட்டம் Gold ஆகும்.',
      'isBot': true,
      'time': '10:02 AM',
    },
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
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
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: IconButton(
              onPressed: () {},
              icon: Icon(Icons.notifications_none_rounded,
                  color: AppTheme.textSecondaryOf(context), size: 22),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
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
        mainAxisAlignment:
            isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
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
              child: const Icon(Icons.smart_toy_rounded,
                  size: 16, color: Colors.white),
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
                crossAxisAlignment:
                    isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isBot ? AppTheme.textPrimaryOf(context) : Colors.white,
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
                border: Border.all(
                  color: AppTheme.dividerOf(context),
                ),
              ),
              child: TextField(
                controller: _messageController,
                style: TextStyle(
                  color: AppTheme.textPrimaryOf(context),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask Assist anything...',
                  hintStyle: TextStyle(
                    color: AppTheme.textHintOf(context),
                  ),
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
              onPressed: () {},
              icon: const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
