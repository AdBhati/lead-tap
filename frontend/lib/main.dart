/// Application entry point.
///
/// Sets up multi-provider state management and named route navigation.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stall_capture/providers/auth_provider.dart';
import 'package:stall_capture/providers/event_provider.dart';
import 'package:stall_capture/services/api_service.dart';
import 'package:stall_capture/screens/login_screen.dart';
import 'package:stall_capture/screens/whatsapp_setup_screen.dart';
import 'package:stall_capture/screens/home_screen.dart';
import 'package:stall_capture/screens/new_event_screen.dart';
import 'package:stall_capture/screens/lead_capture_screen.dart';
import 'package:stall_capture/screens/leads_list_screen.dart';
import 'package:stall_capture/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StallCaptureApp());
}

class StallCaptureApp extends StatelessWidget {
  const StallCaptureApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ApiService is a singleton — shared across all providers
    final apiService = ApiService();

    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService)),
        ChangeNotifierProvider(create: (_) => EventProvider(apiService)),
      ],
      child: MaterialApp(
        title: 'Stall Capture',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _SplashRouter(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/whatsapp-setup': (_) => const WhatsAppSetupScreen(),
          '/home': (_) => const HomeScreen(),
          '/new-event': (_) => const NewEventScreen(),
          '/lead-capture': (_) => const LeadCaptureScreen(),
          '/leads-list': (_) => const LeadsListScreen(),
        },
      ),
    );
  }
}

/// Initial router — checks if user has a stored JWT and redirects accordingly.
class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      await auth.checkAuthStatus();
      if (!mounted) return;

      if (auth.isAuthenticated) {
        if (auth.user!.hasWhatsApp) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          Navigator.of(context).pushReplacementNamed('/whatsapp-setup');
        }
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner_rounded,
                size: 64, color: Color(0xFF1A73E8)),
            SizedBox(height: 16),
            Text(
              'Stall Capture',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF202124),
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}
