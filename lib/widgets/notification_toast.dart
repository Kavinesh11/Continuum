import 'dart:async';
import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../state/notification_state.dart';
import '../theme/app_theme.dart';

/// Wraps [child] and overlays a slide-in banner whenever a new notification
/// is added to [NotificationState]. Mimics the OS push-notification banner.
class NotificationToastLayer extends StatefulWidget {
  final Widget child;
  const NotificationToastLayer({Key? key, required this.child})
      : super(key: key);

  @override
  State<NotificationToastLayer> createState() => _NotificationToastLayerState();
}

class _NotificationToastLayerState extends State<NotificationToastLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  NotificationItem? _current;
  Timer? _dismiss;
  int _lastSeq = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    NotificationState.instance.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    NotificationState.instance.removeListener(_onStateChanged);
    _dismiss?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    final state = NotificationState.instance;
    if (state.toastSeq == _lastSeq) return;
    _lastSeq = state.toastSeq;
    final item = state.toastItem;
    if (item == null) return;

    _dismiss?.cancel();
    setState(() => _current = item);
    _ctrl.forward(from: 0);
    _dismiss = Timer(const Duration(milliseconds: 3800), _slideOut);
  }

  void _slideOut() {
    _ctrl.reverse().then((_) {
      if (mounted) setState(() => _current = null);
    });
  }

  IconData _icon(NotificationItem item) {
    final t = item.title.toLowerCase();
    if (t.contains('claim') || t.contains('approved') || t.contains('rejected')) {
      return Icons.receipt_long_rounded;
    }
    if (t.contains('payout') || t.contains('credited') ||
        t.contains('debited') || t.contains('premium')) {
      return Icons.account_balance_wallet_outlined;
    }
    return Icons.notifications_active_rounded;
  }

  Color _color(NotificationItem item) {
    final t = item.title.toLowerCase();
    if (t.contains('claim') || t.contains('approved') || t.contains('rejected')) {
      return AppTheme.successGreen;
    }
    if (t.contains('payout') || t.contains('credited') ||
        t.contains('debited') || t.contains('premium')) {
      return AppTheme.primary;
    }
    return AppTheme.warningOrange;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_current != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _fade,
                child: _buildBanner(context, _current!),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBanner(BuildContext context, NotificationItem item) {
    final color = _color(item);
    final icon = _icon(item);

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () {
          _dismiss?.cancel();
          _slideOut();
          Navigator.pushNamed(context, AppRoutes.notifications);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          item.timeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textHintOf(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.detail,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textHintOf(context),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
