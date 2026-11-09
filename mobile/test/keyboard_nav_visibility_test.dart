import 'package:camp/core/widgets/camp_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'CampBottomNav hides when keyboard viewInsets.bottom > 0 and restores when reset',
      (WidgetTester tester) async {
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              TextField(
                decoration: InputDecoration(labelText: 'Motorcycle Model'),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Center(
                  child: CampBottomNav(selected: CampTab.home),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially, keyboard is closed: nav is visible
    expect(find.byType(CampBottomNav), findsOneWidget);
    expect(find.byKey(const ValueKey('camp_bottom_nav_visible')), findsOneWidget);
    expect(find.byKey(const ValueKey('camp_bottom_nav_hidden')), findsNothing);
    expect(find.byIcon(Icons.explore_rounded), findsOneWidget);

    // Simulate keyboard opening by setting viewInsets.bottom > 0
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    // Nav is now hidden (renders SizedBox.shrink)
    expect(find.byKey(const ValueKey('camp_bottom_nav_hidden')), findsOneWidget);
    expect(find.byKey(const ValueKey('camp_bottom_nav_visible')), findsNothing);
    expect(find.byIcon(Icons.explore_rounded), findsNothing);

    // Simulate keyboard closing by resetting view insets to 0
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    // Nav is restored and visible again
    expect(find.byKey(const ValueKey('camp_bottom_nav_visible')), findsOneWidget);
    expect(find.byKey(const ValueKey('camp_bottom_nav_hidden')), findsNothing);
    expect(find.byIcon(Icons.explore_rounded), findsOneWidget);
  });
}
