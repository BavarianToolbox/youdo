import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/completion/presentation/completion_screen.dart';
import 'features/history/presentation/history_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/payments/presentation/payment_setup_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/tasks/domain/task.dart';
import 'features/tasks/presentation/task_detail/task_detail_screen.dart';
import 'features/tasks/presentation/task_list/task_list_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final currentUser = ref.watch(currentUserProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/tasks',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoading = authState.isLoading;

      if (isLoading) return null;

      if (!isLoggedIn) {
        if (state.matchedLocation != '/auth') return '/auth';
        return null;
      }

      if (state.matchedLocation == '/auth') {
        final user = currentUser.valueOrNull;
        if (user != null && !user.onboardingComplete) return '/onboarding';
        return '/tasks';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, state, child) =>
            MainScaffold(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/tasks', builder: (_, __) => const TaskListScreen()),
          GoRoute(
            path: '/tasks/new',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, __) => const TaskDetailScreen(taskId: null),
          ),
          GoRoute(
            path: '/tasks/:id',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, state) =>
                TaskDetailScreen(taskId: state.pathParameters['id']),
            routes: [
              GoRoute(
                path: 'complete',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (_, state) {
                  final extra = state.extra as Map<String, dynamic>? ?? {};
                  final task = extra['task'] as Task?;
                  final isOnTime = extra['isOnTime'] as bool? ?? false;
                  if (task == null) return const TaskListScreen();
                  return CompletionScreen(task: task, isOnTime: isOnTime);
                },
              ),
            ],
          ),
          GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/settings/payment',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, __) => const PaymentSetupScreen(),
          ),
        ],
      ),
    ],
  );
});

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _selectedIndex(String location) {
    if (location.startsWith('/tasks')) return 0;
    if (location.startsWith('/history')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _selectedIndex(widget.location);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/tasks');
            case 1:
              context.go('/history');
            case 2:
              context.go('/settings');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline_rounded),
            selectedIcon: Icon(Icons.check_circle_rounded),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class YouDoApp extends ConsumerWidget {
  const YouDoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'You-Do',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
