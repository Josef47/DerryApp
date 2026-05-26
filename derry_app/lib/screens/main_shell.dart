import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    (path: '/home',       icon: Icons.home_rounded,           label: 'Ana Sayfa'),
    (path: '/tasks',      icon: Icons.checklist_rounded,      label: 'Görevler'),
    (path: '/finance',    icon: Icons.account_balance_wallet_rounded, label: 'Finans'),
    (path: '/shopping',   icon: Icons.shopping_cart_rounded,  label: 'Alışveriş'),
    (path: '/activities', icon: Icons.bar_chart_rounded,      label: 'Aktivite'),
  ];

  int _currentIndex(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _currentIndex(location);
    final isHMAsync = ref.watch(isHousemasterProvider);
    final isHM = isHMAsync.value ?? false;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              label: tab.label,
            ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF2D6A4F),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.home_rounded, color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  const Text('Household',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  if (isHM)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Housemaster',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                ],
              ),
            ),
            ...List.generate(_tabs.length, (i) => ListTile(
              leading: Icon(_tabs[i].icon),
              title: Text(_tabs[i].label),
              selected: location.startsWith(_tabs[i].path),
              selectedTileColor: const Color(0xFFB7E4C7).withOpacity(0.3),
              onTap: () {
                context.pop();
                context.go(_tabs[i].path);
              },
            )),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: const Text('Drive Dosyaları'),
              selected: location.startsWith('/drive'),
              selectedTileColor: const Color(0xFFB7E4C7).withOpacity(0.3),
              onTap: () { context.pop(); context.go('/drive'); },
            ),
            if (isHM)
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Ayarlar'),
                selected: location.startsWith('/settings'),
                selectedTileColor: const Color(0xFFB7E4C7).withOpacity(0.3),
                onTap: () { context.pop(); context.go('/settings'); },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await ref.read(authServiceProvider).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}
