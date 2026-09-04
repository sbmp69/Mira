import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants/colors.dart';
import 'services/api.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/call_screen.dart';

void main() {
  runApp(const MiraApp());
}

final _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    final token = await AuthApi.getToken();
    final inAuthGroup = state.matchedLocation == '/login' || state.matchedLocation == '/signup';
    
    if (token == null && !inAuthGroup) {
      return '/login';
    } else if (token != null && inAuthGroup) {
      return '/';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/chat/:id',
      builder: (context, state) {
        return ChatScreen(companionId: state.pathParameters['id']!);
      },
    ),
    GoRoute(
      path: '/call/:id',
      builder: (context, state) {
        return CallScreen(companionId: state.pathParameters['id']!);
      },
    ),
  ],
);

class MiraApp extends StatelessWidget {
  const MiraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mira AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ).apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        ),
      ),
      routerConfig: _router,
    );
  }
}
