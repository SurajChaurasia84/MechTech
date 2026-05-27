import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customer/customer_dashboard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    
    if (appState.currentCustomerName == null) {
      return const LoginScreen();
    } else {
      return const CustomerDashboard();
    }
  }
}
