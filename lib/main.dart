import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'services/mock/mock_database.dart';
import 'services/mock/mock_services.dart';
import 'utils/constants.dart';

const _mockStorageKey = 'turfapp_mock_db_v1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (useMockBackend) {
    final prefs = await SharedPreferences.getInstance();
    final db =
        MockDatabase.fromJsonString(prefs.getString(_mockStorageKey)) ?? MockDatabase.seeded();
    db.onChanged = (json) => prefs.setString(_mockStorageKey, json);
    db.commit(); // save the seed on first launch
    runApp(ProviderScope(overrides: mockBackendOverrides(db), child: const TurfApp()));
    return;
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const ProviderScope(child: TurfApp()));
}
