import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:doc_lookup/app.dart';

void main() {
  setUpAll(() {
    // sqflite has no platform-channel implementation under flutter_test —
    // swap in the pure-Dart FFI backend so LocalDatabase.open() works here.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App opens straight to the library, with no sign-in step', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pump();

    // Confirms there's no auth gate — the Library screen (not a sign-in
    // screen) is what's mounted immediately. The document list itself is
    // still loading at this point (an in-flight sqflite open), which is
    // fine — that's covered live, not in this smoke test.
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });
}
