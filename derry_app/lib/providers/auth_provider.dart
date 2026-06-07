import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../core/constants.dart';

// Pre-loaded in main() before runApp — always available synchronously
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('Override in main()'),
);

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Current logged-in user (loaded from SharedPrefs + Firestore)
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  return ref.read(authServiceProvider).getSessionUser();
});

// Sync providers — read from pre-loaded SharedPreferences
final isLoggedInProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final uid = prefs.getString(AppConstants.prefUserId);
  return uid != null && uid.isNotEmpty;
});

final isHousemasterProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(AppConstants.prefIsHousemaster) ?? false;
});

final isTreasurerProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(AppConstants.prefIsTreasurer) ?? false;
});

final currentUserIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString(AppConstants.prefUserId) ?? '';
});
