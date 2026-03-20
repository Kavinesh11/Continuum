class UIHelpers {
  static String formatCurrency(double amount) {
    if (amount <= 0) return 'Pending';
    return '₹ ${amount.toStringAsFixed(2)}';
  }
}
