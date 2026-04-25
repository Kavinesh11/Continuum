import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../sandbox/driver_provider.dart';
import '../state/demo_orchestrator.dart';
import '../state/notification_state.dart';
import '../theme/app_theme.dart';

class NotificationAction extends StatelessWidget {
  const NotificationAction({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<DriverProvider>();
    final partnerId = provider?.driver.partnerId ?? 'current_worker';

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
              GestureDetector(
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.notifications),
                onLongPress: () =>
                    DemoOrchestrator.instance.seedDemoNotifications(),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: AppTheme.textSecondaryOf(context),
                    size: 22,
                  ),
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
}
