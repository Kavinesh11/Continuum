import 'package:flutter/material.dart';
import '../../sandbox/driver_provider.dart';
import '../../state/notification_state.dart';
import '../../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'All';

  static const _filters = ['All', 'Claims', 'Payouts', 'Alerts'];

  String _category(NotificationItem item) {
    final t = item.title.toLowerCase();
    final d = item.detail.toLowerCase();
    if (t.contains('claim') || t.contains('approved') || t.contains('rejected') ||
        d.contains('claim')) return 'Claims';
    if (t.contains('payout') || t.contains('credited') || t.contains('debited') ||
        t.contains('premium') || d.contains('upi') || d.contains('₹')) return 'Payouts';
    return 'Alerts';
  }

  IconData _icon(NotificationItem item) {
    final cat = _category(item);
    switch (cat) {
      case 'Claims': return Icons.receipt_long_rounded;
      case 'Payouts': return Icons.account_balance_wallet_outlined;
      default: return Icons.notifications_active_rounded;
    }
  }

  Color _color(NotificationItem item) {
    final cat = _category(item);
    switch (cat) {
      case 'Claims': return AppTheme.successGreen;
      case 'Payouts': return AppTheme.primary;
      default: return AppTheme.warningOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<DriverProvider>();
    final partnerId = provider?.driver.partnerId ?? 'current_worker';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          AnimatedBuilder(
            animation: NotificationState.instance,
            builder: (context, _) {
              final count = NotificationState.instance.notificationsFor(partnerId).length;
              if (count == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () {
                  final items = List<NotificationItem>.from(
                    NotificationState.instance.notificationsFor(partnerId),
                  );
                  for (final item in items) {
                    NotificationState.instance.markAsRead(
                      partnerId: partnerId,
                      notificationId: item.id,
                    );
                  }
                },
                child: const Text(
                  'Mark all read',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: NotificationState.instance,
        builder: (context, _) {
          final all = NotificationState.instance.notificationsFor(partnerId);
          final filtered = _filter == 'All'
              ? all
              : all.where((n) => _category(n) == _filter).toList();

          return Column(
            children: [
              _buildFilterChips(context, all),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmpty(context)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) =>
                            _buildCard(ctx, filtered[i], partnerId),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, List<NotificationItem> all) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _filters.map((f) {
          final count = f == 'All'
              ? all.length
              : all.where((n) => _category(n) == f).length;
          final selected = _filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selected,
              label: Text('$f${count > 0 ? " ($count)" : ""}'),
              onSelected: (_) => setState(() => _filter = f),
              selectedColor: AppTheme.primary.withOpacity(0.15),
              checkmarkColor: AppTheme.primary,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: selected
                    ? AppTheme.primary
                    : AppTheme.textSecondaryOf(context),
              ),
              side: BorderSide(
                color: selected
                    ? AppTheme.primary.withOpacity(0.4)
                    : AppTheme.dividerOf(context),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    NotificationItem item,
    String partnerId,
  ) {
    final color = _color(item);
    final icon = _icon(item);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => NotificationState.instance.markAsRead(
        partnerId: partnerId,
        notificationId: item.id,
      ),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.dangerRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.check_rounded, color: AppTheme.dangerRed),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.dividerOf(context)),
          boxShadow: AppTheme.softShadowOf(context),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
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
                        ),
                      ),
                      Text(
                        item.timeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textHintOf(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => NotificationState.instance.markAsRead(
                partnerId: partnerId,
                notificationId: item.id,
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppTheme.successGreen,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 56,
            color: AppTheme.textHintOf(context),
          ),
          const SizedBox(height: 12),
          Text(
            'No notifications',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'New alerts, claim updates and payouts will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textHintOf(context),
            ),
          ),
        ],
      ),
    );
  }
}
