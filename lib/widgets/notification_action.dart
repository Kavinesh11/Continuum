import 'package:flutter/material.dart';

import '../sandbox/driver_provider.dart';
import '../state/notification_state.dart';
import '../theme/app_theme.dart';

class NotificationAction extends StatelessWidget {
  const NotificationAction({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final partnerId = DriverProvider.of(context).driver.partnerId;

    return AnimatedBuilder(
      animation: NotificationState.instance,
      builder: (context, _) {
        final count = NotificationState.instance
            .notificationsFor(partnerId)
            .length;

        return Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () => _showNotificationsDropdown(context, partnerId),
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: AppTheme.textSecondaryOf(context),
                  size: 22,
                ),
              ),
              if (count > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.dangerRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showNotificationsDropdown(
    BuildContext context,
    String partnerId,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (ctx) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 56, right: 12, left: 24),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 340,
                  constraints: const BoxConstraints(maxHeight: 360),
                  decoration: BoxDecoration(
                    color: AppTheme.cardOf(ctx),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppTheme.softShadowOf(ctx),
                    border: Border.all(color: AppTheme.dividerOf(ctx)),
                  ),
                  child: AnimatedBuilder(
                    animation: NotificationState.instance,
                    builder: (context, _) {
                      final items = NotificationState.instance.notificationsFor(
                        partnerId,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                            child: Row(
                              children: [
                                Text(
                                  'Notifications',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimaryOf(ctx),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${items.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textSecondaryOf(ctx),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: AppTheme.dividerOf(ctx)),
                          if (items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(18),
                              child: Center(
                                child: Text(
                                  'No unread notifications',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondaryOf(ctx),
                                  ),
                                ),
                              ),
                            )
                          else
                            Flexible(
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: AppTheme.dividerOf(ctx),
                                ),
                                itemBuilder: (_, index) {
                                  final item = items[index];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    title: Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimaryOf(ctx),
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '${item.detail}\n${item.timeLabel}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondaryOf(ctx),
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                    trailing: IconButton(
                                      tooltip: 'Mark as read',
                                      onPressed: () {
                                        NotificationState.instance.markAsRead(
                                          partnerId: partnerId,
                                          notificationId: item.id,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.check_rounded,
                                        color: AppTheme.successGreen,
                                        size: 22,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
