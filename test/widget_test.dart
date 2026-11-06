
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic Flutter widget test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Campus Supply Desk'),
          ),
        ),
      ),
    );

    expect(find.text('Campus Supply Desk'), findsOneWidget);
  });
}
