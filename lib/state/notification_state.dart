import 'package:flutter/material.dart';

class AppNotificationItem {
  final String id;
  final String title;
  final String detail;
  final String timeLabel;

  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.detail,
    required this.timeLabel,
  });

  AppNotificationItem copyWith({
    String? id,
    String? title,
    String? detail,
    String? timeLabel,
  }) {
    return AppNotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      timeLabel: timeLabel ?? this.timeLabel,
    );
  }
}

class NotificationState extends ChangeNotifier {
  NotificationState._();

  static final NotificationState instance = NotificationState._();

  static const Map<String, List<AppNotificationItem>> _seedByPartnerId = {
    'SWG-9284-912': [
      AppNotificationItem(
        id: 'swg1',
        title: 'Rain trigger detected',
        detail: 'Heavy rainfall in Chennai Zone 4. Auto-claim evaluated.',
        timeLabel: '2 min ago',
      ),
      AppNotificationItem(
        id: 'swg2',
        title: 'Weekly premium paid',
        detail: 'Rs 57 has been debited from your default UPI method.',
        timeLabel: '1 hr ago',
      ),
      AppNotificationItem(
        id: 'swg3',
        title: 'Claim moved to review',
        detail: 'Your disruption claim is now under review.',
        timeLabel: 'Today',
      ),
    ],
    'ZMT-4471-338': [
      AppNotificationItem(
        id: 'zmt1',
        title: 'Order density drop',
        detail: 'Order volume dropped in your active zone by 64 percent.',
        timeLabel: '5 min ago',
      ),
      AppNotificationItem(
        id: 'zmt2',
        title: 'Coverage reminder',
        detail: 'Your plan renewal is due tomorrow. Auto-pay is enabled.',
        timeLabel: 'Today',
      ),
      AppNotificationItem(
        id: 'zmt3',
        title: 'Policy update available',
        detail: 'A new policy note has been added for outage incidents.',
        timeLabel: 'Yesterday',
      ),
    ],
    'SWG-7731-556': [
      AppNotificationItem(
        id: 'swg4',
        title: 'Road closure alert',
        detail: 'Two roads near your area are blocked. Route risk increased.',
        timeLabel: 'Just now',
      ),
      AppNotificationItem(
        id: 'swg5',
        title: 'Auto-claim approved',
        detail: 'A zero-touch claim was approved and payout is initiated.',
        timeLabel: '40 min ago',
      ),
      AppNotificationItem(
        id: 'swg6',
        title: 'Profile verification due',
        detail: 'Please confirm emergency contact to keep coverage active.',
        timeLabel: 'Today',
      ),
    ],
  };

  final Map<String, List<AppNotificationItem>> _itemsByPartnerId = {};

  List<AppNotificationItem> notificationsFor(String partnerId) {
    final existing = _itemsByPartnerId[partnerId];
    if (existing != null) {
      return List<AppNotificationItem>.unmodifiable(existing);
    }

    final seeded =
        (_seedByPartnerId[partnerId] ?? const <AppNotificationItem>[])
            .map((item) => item.copyWith())
            .toList();
    _itemsByPartnerId[partnerId] = seeded;
    return List<AppNotificationItem>.unmodifiable(seeded);
  }

  void markAsRead({required String partnerId, required String notificationId}) {
    final current =
        _itemsByPartnerId[partnerId] ??
        (_seedByPartnerId[partnerId] ?? const <AppNotificationItem>[])
            .map((item) => item.copyWith())
            .toList();

    final next = current.where((n) => n.id != notificationId).toList();
    if (next.length == current.length) return;

    _itemsByPartnerId[partnerId] = next;
    notifyListeners();
  }
}
