import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:papyrus/main.dart';
import 'package:papyrus/core/auth_provider.dart';
import 'package:papyrus/core/shop_provider.dart';

void main() {
  testWidgets('Papyrus Smoke Test - App Starts', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ShopProvider()),
        ],
        child: const MyApp(),
      ),
    );

    // Verify that the app starts up. 
    // Since it's a fresh start, it should show 'Sign In' or 'Papyrus'.
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // We can also check for a specific widget that should be present initially.
    // For example, the branding text.
    expect(find.textContaining('Papyrus'), findsWidgets);
  });
}
