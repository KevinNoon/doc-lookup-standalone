import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage_persist_web.dart' if (dart.library.io) 'core/storage_persist_stub.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(requestPersistentStorage());
  runApp(const ProviderScope(child: App()));
}
