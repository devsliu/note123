import 'package:drift/drift.dart';

@DataClassName('Operate')
class Operates extends Table {
  static const typeLocal = "local";
  static const typeDownload = "download";
  static const typeUpload = "upload";
  static const typeError = "error";

  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get value => text()();
  IntColumn get time => integer()();
}
