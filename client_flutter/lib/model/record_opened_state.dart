import 'package:flutter/widgets.dart';

/// Tracks which folder and record are currently open in the UI.
///
/// This is navigation/selection state rather than part of the record tree
/// structure, so it lives separately from [RecordTree]. The tree resolves the
/// stored path/uuid to actual nodes/content when needed.
class RecordOpenedState {
  static final RecordOpenedState instance = RecordOpenedState._();
  RecordOpenedState._();

  //path
  final ValueNotifier<String> openedFolderNotifier = ValueNotifier<String>("/");
  //uuid
  final ValueNotifier<String> openedFileNotifier = ValueNotifier<String>("");

  void setOpenedFile(String uuid) {
    openedFileNotifier.value = uuid;
  }

  void setOpenedFolder(String path) {
    openedFolderNotifier.value = path;
  }
}
