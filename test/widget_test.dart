import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:provider/provider.dart';
import 'package:mechtech/main.dart';
import 'package:mechtech/services/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const MechTechApp(),
      ),
    );

    // Verify that login elements exist
    expect(find.text('MechTech'), findsOneWidget);
    expect(find.text('Premium Mechanic Service App'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
