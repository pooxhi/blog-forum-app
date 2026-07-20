import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/posts/post_list_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/posts/create_post_screen.dart';
import 'screens/posts/post_detail_screen.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authProvider, // rebuild routes when auth state changes
    redirect: (context, state) {
      final loggedIn = authProvider.isAuthenticated;
      final loggingIn = state.matchedLocation == '/login';
      final registering = state.matchedLocation == '/register';

      // Posts are public, so no redirect needed for '/' when logged out.
      // Only guard truly protected routes and the auth pages themselves.
      if (!loggedIn && !loggingIn && !registering) {
        // e.g. protect '/create-post' but allow public browsing of '/'
        final protectedPaths = ['/create-post', '/edit-post'];
        final isProtected = protectedPaths.any(
          (p) => state.matchedLocation.startsWith(p),
        );
        if (isProtected) return '/login';
      }

      if (loggedIn && (loggingIn || registering)) {
        return '/'; // already logged in, don't show login/register
      }

      return null; // no redirect
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const PostListScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/create-post',
        builder: (context, state) => const CreatePostScreen(),
      ),
      GoRoute(
        path: '/edit-post/:id',
        builder:
            (context, state) =>
                CreatePostScreen(postId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/post/:id',
        builder:
            (context, state) =>
                PostDetailScreen(postId: state.pathParameters['id']!),
      ),
    ],
  );
}
