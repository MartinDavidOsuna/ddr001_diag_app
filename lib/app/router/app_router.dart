import 'package:go_router/go_router.dart';

import '../../core/services/app_state.dart';
import '../../features/auth/auth_pages.dart';
import '../../features/home/home_page.dart';
import '../../features/hydrants/hydrant_pages.dart';
import '../../features/map/map_page.dart';
import '../../features/profile/profile_pages.dart';
import '../../features/shell/main_shell.dart';
import '../../features/sync/sync_page.dart';

GoRouter createRouter(AppState state) => GoRouter(
  initialLocation: '/',
  refreshListenable: state,
  redirect: (context, route) {
    if (route.matchedLocation == '/' || route.matchedLocation == '/login') {
      return null;
    }
    if (!state.authenticated) {
      return '/login';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, _) => const SplashPage()),
    GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
    ShellRoute(
      builder: (_, state, child) =>
          MainShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomePage()),
        GoRoute(path: '/hydrants', builder: (_, _) => const HydrantsPage()),
        GoRoute(path: '/map', builder: (_, _) => const MapPage()),
        GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
      ],
    ),
    GoRoute(
      path: '/hydrants/:id',
      builder: (_, state) => HydrantDetailPage(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/new-survey',
      builder: (_, _) => const PlaceholderPage(
        title: 'Nuevo levantamiento',
        message:
            'El flujo completo para registrar hidrantes en campo se implementará en la Etapa 2.',
      ),
    ),
    GoRoute(
      path: '/inspection/:id/:type',
      builder: (_, state) => PlaceholderPage(
        title: state.pathParameters['type'] == 'a'
            ? 'Diagnóstico F02-A'
            : 'Diagnóstico F02-B',
        message:
            'El formulario completo se implementará en la Etapa 2. Esta pantalla conserva la navegación y el contexto del hidrante ${state.pathParameters['id']}.',
      ),
    ),
    GoRoute(path: '/sync', builder: (_, _) => const SyncPage()),
    GoRoute(path: '/manual', builder: (_, _) => const ManualPage()),
    GoRoute(path: '/update', builder: (_, _) => const UpdatePage()),
  ],
);
