import 'package:intl/intl.dart';

class AppConstants {
  // Firestore collections
  static const String colUsers = 'users';
  static const String colOneTimeKeys = 'oneTimeKeys';
  static const String colTasks = 'tasks';
  static const String colCompletions = 'completions';
  static const String colActivityTypes = 'activityTypes';
  static const String colActivityLogs = 'activityLogs';
  static const String colFinanceEntries = 'financeEntries';
  static const String colFinanceBalance = 'financeBalance';
  static const String colShoppingItems = 'shoppingItems';
  static const String colShoppingCategories = 'shoppingCategories';
  static const String colLoyaltyCards = 'loyaltyCards';
  static const String colDriveLinks = 'driveLinks';
  static const String colSettings = 'settings';

  // Singleton doc IDs
  static const String docBalance = 'balance';
  static const String docSettings = 'appSettings';

  // SharedPreferences keys
  static const String prefUserId = 'userId';
  static const String prefUserName = 'userName';
  static const String prefIsHousemaster = 'isHousemaster';
  static const String prefIsTreasurer = 'isTreasurer';

  // Roles
  static const String roleHousemaster = 'housemaster';
  static const String roleMember = 'member';

  // Task types
  static const String taskRecurring = 'recurring';
  static const String taskOneTime = 'one-time';

  // Recurrence types
  static const String recNone = 'none';
  static const String recDaily = 'daily';
  static const String recWeekly = 'weekly';
  static const String recCustom = 'custom';

  // Urgency levels
  static const String urgencyLow = 'Low';
  static const String urgencyMedium = 'Medium';
  static const String urgencyHigh = 'High';

  // Week label: ISO 8601 week, Monday start, format YYYY-Wnn
  static String currentWeekLabel() {
    final now = DateTime.now();
    // ISO week: Monday = 1
    final dayOfWeek = now.weekday; // 1=Mon, 7=Sun
    final monday = now.subtract(Duration(days: dayOfWeek - 1));
    final year = monday.year;
    final startOfYear = DateTime(year, 1, 1);
    final dayOfYear = monday.difference(startOfYear).inDays + 1;
    final weekNum = ((dayOfYear - monday.weekday + 10) / 7).floor();
    return '$year-W${weekNum.toString().padLeft(2, '0')}';
  }

  static String weekLabelForDate(DateTime date) {
    final dayOfWeek = date.weekday;
    final monday = date.subtract(Duration(days: dayOfWeek - 1));
    final year = monday.year;
    final startOfYear = DateTime(year, 1, 1);
    final dayOfYear = monday.difference(startOfYear).inDays + 1;
    final weekNum = ((dayOfYear - monday.weekday + 10) / 7).floor();
    return '$year-W${weekNum.toString().padLeft(2, '0')}';
  }

  static String formatDate(DateTime dt) =>
      DateFormat('dd MMM yyyy').format(dt);

  static String formatDateTime(DateTime dt) =>
      DateFormat('dd MMM yyyy HH:mm').format(dt);

  static String formatAmount(double amount) =>
      NumberFormat.currency(symbol: '€', decimalDigits: 2).format(amount);
}
