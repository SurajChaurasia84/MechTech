import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/app_state.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customer/customer_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Set system navigation/status bar styling for seamless UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D0B18),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MechTechApp(),
    ),
  );
}

class MechTechApp extends StatelessWidget {
  const MechTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MechTech',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0B18),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFF00B0FF),
          background: Color(0xFF0D0B18),
          surface: Color(0xFF161426),
          error: Colors.redAccent,
        ),
        useMaterial3: true,
      ),
      home: const MainGate(),
    );
  }
}

class MainGate extends StatelessWidget {
  const MainGate({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // Still resolving Firebase auth state — show splash to avoid login screen flash
    if (appState.isAuthLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0B18),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00E676),
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (appState.user != null) {
      return const CustomerDashboard();
    } else {
      return const LoginScreen();
    }
  }
}
