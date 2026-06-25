import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders smoke screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Eco')));

    expect(find.text('Eco'), findsOneWidget);
  });
}
