import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';

/// Singleton database provider — available throughout the app
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
