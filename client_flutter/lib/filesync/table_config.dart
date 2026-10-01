import 'package:drift/drift.dart';

@DataClassName('KVConfig')
class KVConfigs extends Table {
  // Last synced maximum version number (inclusive)
  static const String lastSyncedVersion = 'last_synced_version';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
