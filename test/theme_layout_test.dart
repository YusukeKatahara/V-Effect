import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_effect/config/theme.dart';

void main() {
  group('Absolute Monochrome Theme Layout Definitions Test', () {
    testWidgets('Light Theme builds and renders common components without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Theme Test - Light'),
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Card Content'),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Elevated Button'),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Outlined Button'),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Text Button'),
                  ),
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'Label Text',
                      hintText: 'Hint Text',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const Divider(),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
            bottomNavigationBar: NavigationBar(
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
              selectedIndex: 0,
            ),
          ),
        ),
      );

      // Verify that the tree built successfully and no exception was thrown
      expect(find.text('Theme Test - Light'), findsOneWidget);
      expect(find.text('Card Content'), findsOneWidget);
      expect(find.text('Elevated Button'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('Dark Theme builds and renders common components without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Theme Test - Dark'),
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Card Content'),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Elevated Button'),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Outlined Button'),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Text Button'),
                  ),
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'Label Text',
                      hintText: 'Hint Text',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const Divider(),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
            bottomNavigationBar: NavigationBar(
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
              selectedIndex: 0,
            ),
          ),
        ),
      );

      // Verify that the tree built successfully and no exception was thrown
      expect(find.text('Theme Test - Dark'), findsOneWidget);
      expect(find.text('Card Content'), findsOneWidget);
      expect(find.text('Elevated Button'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });
}
