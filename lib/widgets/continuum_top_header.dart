import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../sandbox/driver_provider.dart';
import '../sandbox/sandbox_drivers.dart';
import '../theme/app_theme.dart';

class ContinuumTopHeader extends StatefulWidget implements PreferredSizeWidget {
  final String title;

  const ContinuumTopHeader({Key? key, this.title = 'CONTINUUM'})
    : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<ContinuumTopHeader> createState() => _ContinuumTopHeaderState();
}

class _ContinuumTopHeaderState extends State<ContinuumTopHeader> {
  @override
  Widget build(BuildContext context) {
    final driver = DriverProvider.of(context).driver;
    final notifications = ContinuumNotificationCenter.of(driver);
    final hasUnread = notifications.any((item) => !item.isRead);

    return AppBar(
      title: Text(widget.title),
      leading: GestureDetector(
        onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.accentGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                driver.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications_outlined,
                  color: AppTheme.textSecondaryOf(context),
                  size: 22,
                ),
                onPressed: () async {
                  await _showNotificationsDropdown(context, driver);
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
              if (hasUnread)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showNotificationsDropdown(
    BuildContext context,
    SandboxDriver driver,
  ) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'notifications',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, __) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final notifications = ContinuumNotificationCenter.of(driver);
            return GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.translucent,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    top:
                        MediaQuery.of(context).padding.top + kToolbarHeight + 4,
                    right: 16,
                  ),
                  child: GestureDetector(
                    onTap: () {},
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.96, end: 1.0),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          alignment: Alignment.topRight,
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          width: 320,
                          constraints: const BoxConstraints(maxHeight: 340),
                          decoration: BoxDecoration(
                            color: AppTheme.cardOf(context),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(
                              color: AppTheme.dividerOf(context),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  10,
                                  8,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Notifications',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: notifications.isEmpty
                                          ? null
                                          : () {
                                              ContinuumNotificationCenter.markAllRead(
                                                driver,
                                              );
                                              setDialogState(() {});
                                              setState(() {});
                                            },
                                      child: const Text('Mark all as read'),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              if (notifications.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 18,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.notifications_off_outlined,
                                        size: 18,
                                        color: AppTheme.textSecondaryOf(
                                          context,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'None',
                                        style: TextStyle(
                                          color: AppTheme.textSecondaryOf(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Flexible(
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    itemCount: notifications.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final item = notifications[index];
                                      return ListTile(
                                        dense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 2,
                                            ),
                                        leading: Icon(
                                          _iconForType(item.type),
                                          size: 18,
                                          color: AppTheme.primary,
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: item.isRead
                                                      ? FontWeight.w500
                                                      : FontWeight.w700,
                                                  color: AppTheme.textPrimaryOf(
                                                    context,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (!item.isRead)
                                              Container(
                                                width: 7,
                                                height: 7,
                                                margin: const EdgeInsets.only(
                                                  left: 6,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFEF4444),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        subtitle: Text(
                                          item.time,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondaryOf(
                                              context,
                                            ),
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'Mark as read',
                                              onPressed: item.isRead
                                                  ? null
                                                  : () {
                                                      ContinuumNotificationCenter.markRead(
                                                        driver,
                                                        item.id,
                                                      );
                                                      setDialogState(() {});
                                                      setState(() {});
                                                    },
                                              icon: const Icon(
                                                Icons.done_rounded,
                                                size: 18,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Delete',
                                              onPressed: () {
                                                ContinuumNotificationCenter.delete(
                                                  driver,
                                                  item.id,
                                                );
                                                setDialogState(() {});
                                                setState(() {});
                                              },
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  IconData _iconForType(String type) {
    if (type == 'completed') return Icons.check_circle_outline;
    if (type == 'failed') return Icons.error_outline;
    if (type == 'cancelled') return Icons.remove_circle_outline;
    return Icons.notifications_none_rounded;
  }
}

class _NotificationItem {
  final String id;
  final String title;
  final String time;
  final String type;
  bool isRead;

  _NotificationItem({
    required this.id,
    required this.title,
    required this.time,
    required this.type,
    required this.isRead,
  });
}

class ContinuumNotificationCenter {
  static final Map<String, List<_NotificationItem>> _itemsByDriver = {};

  static List<_NotificationItem> of(SandboxDriver driver) {
    return _itemsByDriver.putIfAbsent(driver.partnerId, () {
      final orders = [...driver.orderHistory]
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return orders.take(8).map((order) {
        final status = order.status;
        final title = status == 'completed'
            ? 'Order ${order.orderId} completed'
            : 'Order ${order.orderId} $status';
        return _NotificationItem(
          id: order.orderId,
          title: title,
          time: _relativeTime(order.timestamp),
          type: status,
          isRead: false,
        );
      }).toList();
    });
  }

  static void markRead(SandboxDriver driver, String id) {
    final items = of(driver);
    for (final item in items) {
      if (item.id == id) {
        item.isRead = true;
        break;
      }
    }
  }

  static void markAllRead(SandboxDriver driver) {
    final items = of(driver);
    for (final item in items) {
      item.isRead = true;
    }
  }

  static void delete(SandboxDriver driver, String id) {
    final items = of(driver);
    items.removeWhere((item) => item.id == id);
  }

  static String _relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
