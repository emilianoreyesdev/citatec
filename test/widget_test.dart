import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Citatec - prueba básica de interfaz', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Bienvenido a Citatec'),
          ),
        ),
      ),
    );

    expect(find.text('Bienvenido a Citatec'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}