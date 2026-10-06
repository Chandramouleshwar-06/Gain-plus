import 'package:gain_plus/services/database_service.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Points sqflite at the desktop FFI implementation for tests.
void useFfiDatabase() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

Future<String> testDbPath() async => join(await getDatabasesPath(), DatabaseService.fileName);

/// Closes the app database and deletes its file, so the next access creates
/// a fresh one.
Future<void> resetDatabase() async {
  await DatabaseService.instance.close();
  await deleteDatabase(await testDbPath());
}
