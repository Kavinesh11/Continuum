import 'package:flutter/foundation.dart';

class NotificationItem {
  final String id;
  final String title;
  final String detail;
  final String timeLabel;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.detail,
    required this.timeLabel,
  });
}

class NotificationState extends ChangeNotifier {
  NotificationState._();
  static final NotificationState instance = NotificationState._();

  final Map<String, List<NotificationItem>> _unreadByPartner = {};

  // ── Toast support ──────────────────────────────────────────────────────────
  // Increments each time a new notification arrives; toast layer watches this.
  int _toastSeq = 0;
  NotificationItem? _toastItem;

  int get toastSeq => _toastSeq;
  NotificationItem? get toastItem => _toastItem;

  // ── Inbox ──────────────────────────────────────────────────────────────────

  List<NotificationItem> notificationsFor(String partnerId) {
    return List<NotificationItem>.unmodifiable(
      _unreadByPartner[partnerId] ?? const [],
    );
  }

  void setUnreadNotifications(
    String partnerId,
    List<NotificationItem> notifications,
  ) {
    _unreadByPartner[partnerId] = List<NotificationItem>.from(notifications);
    notifyListeners();
  }

  void addNotification(String partnerId, NotificationItem item) {
    final list = _unreadByPartner.putIfAbsent(partnerId, () => []);
    list.insert(0, item);
    _toastSeq++;
    _toastItem = item;
    notifyListeners();
  }

  void markAsRead({required String partnerId, required String notificationId}) {
    final items = _unreadByPartner[partnerId];
    if (items == null || items.isEmpty) return;
    items.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  void clearPartner(String partnerId) {
    _unreadByPartner.remove(partnerId);
    notifyListeners();
  }

  void clearAll() {
    _unreadByPartner.clear();
    notifyListeners();
  }
}
