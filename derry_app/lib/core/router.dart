import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/home/dashboard_screen.dart';
import '../screens/tasks/tasks_screen.dart';
import '../screens/tasks/task_form_screen.dart';
import '../screens/activities/activities_screen.dart';
import '../screens/finance/finance_screen.dart';
import '../screens/finance/expense_form_screen.dart';
import '../screens/shopping/shopping_screen.dart';
import '../screens/shopping/loyalty_cards_screen.dart';
import '../screens/drive/drive_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/user_management_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final isLoggedIn = userId != null && userId.isNotEmpty;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/tasks',
            builder: (context, state) => const TasksScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const TaskFormScreen(),
              ),
              GoRoute(
                path: ':taskId/edit',
                builder: (context, state) => TaskFormScreen(
                  taskId: state.pathParameters['taskId'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/activities',
            builder: (context, state) => const ActivitiesScreen(),
          ),
          GoRoute(
            path: '/finance',
            builder: (context, state) => const FinanceScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const ExpenseFormScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/shopping',
            builder: (context, state) => const ShoppingScreen(),
            routes: [
              GoRoute(
                path: 'loyalty-cards',
                builder: (context, state) => const LoyaltyCardsScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/drive',
            builder: (context, state) => const DriveScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'users',
                builder: (context, state) => const UserManagementScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
});
