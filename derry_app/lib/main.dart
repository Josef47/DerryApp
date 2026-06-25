import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  const useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
  debugPrint('🚀 main() kDebugMode=$kDebugMode useEmulator=$useEmulator');

  // Lokal geliştirme: emulatorlara bağlan
  if (useEmulator) {
    debugPrint('🔧 Emulator bloğuna giriliyor...');
    const host = 'localhost';
    const timeout = Duration(seconds: 5);
    try {
      await FirebaseAuth.instance
          .useAuthEmulator(host, 9099)
          .timeout(timeout);
    } catch (_) {}
    try {
      FirebaseFirestore.instance.settings = const Settings(
        host: 'localhost:8080',
        sslEnabled: false,
        persistenceEnabled: false,
        webExperimentalForceLongPolling: true,
      );
      debugPrint('✅ Firestore emulator settings OK');
    } catch (e) {
      debugPrint('❌ Firestore settings error: $e');
    }
    try {
      await FirebaseStorage.instance
          .useStorageEmulator(host, 9199)
          .timeout(timeout);
    } catch (_) {}
    debugPrint('🔧 Firebase Emulators aktif (auth:9099 firestore:8080 storage:9199)');
    await _seedEmulator();
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const HouseholdApp(),
  ));
}

Future<void> _seedEmulator() async {
  final db = FirebaseFirestore.instance;
  try {
    final keyRef = db.collection('oneTimeKeys').doc('HM-INIT-LOCAL');
    final snap = await keyRef.get().timeout(const Duration(seconds: 5));
    if (!snap.exists) {
      await keyRef.set({
        'key': 'HM-INIT-LOCAL',
        'userId': 'housemaster_001',
        'name': 'Housemaster',
        'role': 'housemaster',
        'isHousemaster': true,
        'used': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await db.collection('settings').doc('appSettings').set({
        'houseName': 'Bizim Ev',
        'reminderTime': '08:00',
        'timezone': 'Europe/Amsterdam',
        'dutyDayOfWeek': 3,
      });
      for (final zone in [
        {'name': 'Mutfak', 'iconName': 'kitchen', 'order': 0},
        {'name': 'Banyo & Tuvalet', 'iconName': 'bathroom', 'order': 1},
        {'name': 'Salon', 'iconName': 'living', 'order': 2},
        {'name': '3. Kat', 'iconName': 'stairs', 'order': 3},
      ]) {
        await db.collection('dutyZones').add({
          ...zone,
          'miniTasks': <Map<String, dynamic>>[],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      for (final entry in {
        'cat_mutfak': 'Mutfak',
        'cat_banyo': 'Banyo',
        'cat_temizlik': 'Temizlik',
        'cat_diger': 'Diğer',
      }.entries) {
        await db.collection('shoppingCategories').doc(entry.key).set({
          'name': entry.value,
          'createdBy': 'housemaster_001',
        });
      }
      debugPrint('🌱 Emulator seed verisi yüklendi.');
    } else {
      debugPrint('🌱 Emulator zaten seed edilmiş.');
    }
  } catch (e) {
    debugPrint('⚠️ Seed başarısız (emulator hazır değil?): $e');
  }
}

class HouseholdApp extends ConsumerWidget {
  const HouseholdApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Household',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
