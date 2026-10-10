import 'dart:async';
import 'dart:io';

import 'package:note123/filesync/file_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:note123/filesync/database.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/local_record_ext.dart';
import 'package:note123/model/record_utils.dart';
import 'package:note123/utils/app_logger.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/utils/object_ref.dart';
import 'package:note123/ui/desktop/desktop_record_detail_page.dart';

/// Unified page state: mode + payload + buildCount.
/// buildCount is reset to 0 by setStateMode on every state transition, then incremented
/// by build() on each frame. Subclasses use buildCount == 0 to detect "first build after
/// state change" — the signal to (re)initialize document content.
class PageState {
  static const modeLoad = 1;
  static const modePass = 2;
  static const modeNormal = 3;

  final int mode;
  final Object? payload; // pass=encrypted String, normal=plaintext String, load=null
  int buildCount; // 0 = first build for this state; incremented by build()

  PageState(this.mode, [this.payload, this.buildCount = 0]);

  bool get isLoad => mode == modeLoad;
  bool get isPass => mode == modePass;
  bool get isNormal => mode == modeNormal;

  String? get encryptedContent => mode == modePass ? payload as String? : null;
  String? get plaintextContent => mode == modeNormal ? payload as String? : null;
}

abstract class BaseRecordEditPage extends StatefulWidget {
  final TreeContentFile record;
  // Callback when record is deleted remotely; desktop uses it to close tab, mobile defaults to Navigator.pop
  final VoidCallback? onRecordDeleted;

  const BaseRecordEditPage({super.key, required this.record, this.onRecordDeleted});
}

abstract class BaseRecordEditPageState<T extends BaseRecordEditPage> extends State<T>
    with WidgetsBindingObserver
    implements DetailTabPageState {
  PageState pageState = PageState(PageState.modeLoad);
  String? _password; // Save unlock password
  int _saveCount = 0; // Track save count
  bool isContentChanged = false; // Whether content has been modified
  bool _isInForeground = true; // Whether currently in foreground
  Future<void>? _saveFuture; // Coalesce concurrent save calls
  final ObjectRef<String> _contentMd5 = ObjectRef(""); // Track content md5 for diff comparison

  /// Transition to a new page state; buildCount resets to 0 so the next build
  /// signals a fresh state transition.
  void setStateMode(int mode, [Object? payload]) {
    setState(() {
      pageState = PageState(mode, mode == PageState.modeLoad ? null : payload)..buildCount = 0;
    });
  }

  // Track last known LocalRecord (all final, replaced as a whole during sync) for diff comparison
  LocalRecord? _lastKnownRecord;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _lastKnownRecord = widget.record.record;
    Repository.get().recordTree.refreshNotifier.addListener(_onTreeChanged);

    // loadContent() routes locked records to password mode (sPageModePass)
    loadContent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Repository.get().recordTree.refreshNotifier.removeListener(_onTreeChanged);
    // Kick off save chain — coalescing inside saveRecord guarantees latest dirty content
    // gets saved even if a prior save is still in-flight. The returned Future continues
    // on the Dart isolate after dispose; the isolate stays alive until save completes.
    saveRecord();
    super.dispose();
  }

  /// Listen to recordTree changes, compare before/after LocalRecord for this record:
  /// - Deleted remotely → close page (only when no unsaved edits)
  /// - File content change (md5) → re-download and refresh UI (only when no unsaved edits)
  /// - Title change → update title bar
  Future<void> _onTreeChanged() async {
    if (!mounted) return;
    final fileStore = Repository.get().fileStore;
    if (fileStore == null) return;
    final tree = Repository.get().recordTree;
    // Only process events involving this record's uuid, ignore unrelated changes directly
    final events = tree.refreshNotifier.value;
    final myUuid = widget.record.uuid;
    final hit = events.any(
      (e) => (e.type == RecordEvent.typeDeleteRecord || e.type == RecordEvent.typeUpsertRecord) && e.value2 == myUuid,
    );
    if (!hit) return;

    final current = tree.findFile(myUuid);

    // Record has been deleted
    if (current == null) {
      if (isContentChanged) return; // Has unsaved edits, don't close
      if (widget.onRecordDeleted != null) {
        widget.onRecordDeleted!();
      } else {
        Navigator.of(context).maybePop();
      }
      return;
    }

    final newRecord = current.record;
    final oldRecord = _lastKnownRecord;
    // record reference unchanged means this record wasn't updated, no need to handle
    if (identical(oldRecord, newRecord)) return;
    _lastKnownRecord = newRecord;

    // Title change: always update (doesn't affect editing content)
    if (oldRecord?.localName != newRecord.localName) {
      if (mounted) setState(() {});
    }

    if (isContentChanged) return;
    if (newRecord.syncConflict) return;
    if (_contentMd5.value != "" && _contentMd5.value == newRecord.localMd5) return;

    await loadContent();
  }

  void onPageFocusChanged(bool hasFocus) {
    if (!hasFocus) {
      saveRecord();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // When app goes to background or loses focus, save edits and sync
      onPageFocusChanged(false);
    } else if (state == AppLifecycleState.resumed && isInForeground) {
      onPageFocusChanged(true);
    }
  }

  void undo();
  void redo();

  void setInForeground(bool value) {
    bool wasInForeground = _isInForeground;
    _isInForeground = value;
    if (!value && wasInForeground) {
      onPageFocusChanged(false);
    }
    if (value && !wasInForeground) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        onPageFocusChanged(true);
      }
    }
  }

  bool get isInForeground => _isInForeground;

  @override
  Widget build(BuildContext context) {
    // First build for this state → reload content; subsequent rebuilds don't.
    final reload = pageState.buildCount == 0;
    pageState.buildCount++;

    Widget body = ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: pageState.isPass
          ? buildModePasswordWidget(pageState.encryptedContent!, reload)
          : pageState.isLoad
          ? buildModeLoadingWidget()
          : buildContentWidget(pageState.plaintextContent!, reload),
    );
    if (!pageState.isNormal) {
      return body;
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          saveRecord(); // Execute function directly
        },
        // Undo: Ctrl + Z
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
          undo();
        },

        // Redo: Ctrl + Shift + Z
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): () {
          redo();
        },
      },
      // Focus wraps to provide focus scope for Shortcuts (Ctrl+Z etc).
      // Mobile doesn't need auto-focus — let logic in initState/onPageFocusChanged decide when to pop keyboard.
      child: Focus(autofocus: Utils.isDesktop(), child: body),
    );
  }

  Widget buildModeLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [CircularProgressIndicator(), SizedBox(height: 16), Text(l10n.loading)],
      ),
    );
  }

  Widget buildModePasswordWidget(String encryptedContent, bool reload) {
    return UnlockContentWidget(
      encryptedContent: encryptedContent,
      onUnlocked: (context, password, plaintext) {
        _password = password;
        setStateMode(PageState.modeNormal, plaintext);
      },
    );
  }

  Future<void> loadContent() async {
    setStateMode(PageState.modeLoad);

    LocalRecord record = widget.record.record;
    FileStore? fileStore = Repository.get().fileStore;
    if (fileStore == null) {
      return;
    }

    File file = File(fileStore.getWorkFile(record.uuid));
    if (record.remoteFileVersion > 0 && !file.existsSync()) {
      file = File(fileStore.getBaseFile(record.uuid));
      if (!file.existsSync()) {
        await fileStore.downloadBaseFile(record.uuid);
      }
    }
    if (!file.existsSync()) {
      file = File(fileStore.getWorkFile(record.uuid));
    }
    String content = "";
    if (file.existsSync()) {
      try {
        content = file.readAsStringSync();
        _contentMd5.value = Utils.generateMd5(content);
      } catch (e) {
        AppLogger.e("Failed to read file: $e");
      }
    }

    // If record is locked, unlock via UnlockContentWidget (password input + errors inside widget)
    if (record.localLocked == 1 && content.isNotEmpty) {
      // Try saved password first (auto re-unlock after remote refresh)
      if (_password != null) {
        final decrypted = Utils.decryptContent(content, _password!);
        if (decrypted != null) {
          setStateMode(PageState.modeNormal, decrypted);
          return;
        }
        _password = null;
        if (mounted) {
          // Unlock failed, re-show password input screen
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordIncorrect)));
        }
      }
      // Widget decrypts and calls back with plaintext
      setStateMode(PageState.modePass, content);
      return;
    } else if (record.localLocked != 1) {
      _password = null; // Password becomes plaintext after version upgrade
    }

    setStateMode(PageState.modeNormal, content);
  }

  (String content, String name) formatContent();

  /// Save edit. Returns the Future tracking this save (or the in-flight one if coalesced).
  /// Coalesce strategy: if a save is already running AND new edits arrived, it chains a
  /// follow-up save AFTER the current one finishes — never drops the latest dirty state.
  Future<void>? saveRecord() {
    if (!isContentChanged) {
      return _saveFuture; // return in-progress Future if any, otherwise null
    }

    if (_saveFuture != null) {
      // A save is in-flight and new edits arrived — queue a follow-up after it completes
      final current = _saveFuture!;
      _saveFuture = current.then((_) async {
        if (isContentChanged) {
          // _saveFuture is now null (cleared by the in-flight Future's whenComplete),
          // so the recursive call will start a fresh save and return its Future
          await saveRecord();
        }
      });
      return _saveFuture;
    }

    LocalRecord record = widget.record.record;
    var (String content, String name) = formatContent();

    if (name.isEmpty) {
      name = RecordUtils.generateRecordName();
    }

    _saveCount++;
    isContentChanged = false;

    _saveFuture =
        saveWorkFile(
              uuid: record.uuid,
              path: record.localPath,
              name: name,
              content: content,
              locked: record.localLocked,
              password: _password,
              md5Ref: _contentMd5,
            )
            .catchError((e) {
              AppLogger.e("[BaseEditPage] save failed: $e");
            })
            .whenComplete(() {
              _saveFuture = null;
            });
    return _saveFuture;
  }

  /// Write content to work file + update DB metadata. Handles post-encryption md5.
  /// Compares computed md5 against [md5Ref.value] — if equal (no change), skips write.
  /// Otherwise updates [md5Ref.value] with the new md5 so caller stays in sync.
  static Future<void> saveWorkFile({
    required String uuid,
    required String path,
    required String name,
    required String content,
    required ObjectRef<String> md5Ref,
    int locked = 0,
    String? password,
  }) async {
    final fileStore = Repository.get().fileStore;
    if (fileStore == null) {
      AppLogger.w("[BaseEditPage] fileStore unavailable, uuid=$uuid save dropped");
      return;
    }
    int effLocked = locked;
    String? writeContent = content;
    if (password != null) {
      final enc = Utils.encryptContent(content, password);
      if (enc != null) {
        writeContent = enc;
      } else {
        effLocked = 0;
      }
    } else {
      effLocked = 0;
    }
    // md5 is synchronous — compare & update before any await
    final md5 = Utils.generateMd5(writeContent);
    if (md5 == md5Ref.value) {
      return;
    }
    md5Ref.value = md5;
    await File(fileStore.getWorkFile(uuid)).writeAsString(writeContent);
    await Repository.get().editRecord(
      uuid,
      true,
      DateTime.now().millisecondsSinceEpoch,
      name: name,
      locked: effLocked,
      md5: md5,
    );
  }

  Widget buildContentWidget(String plaintext, bool reload);
}

/// Password unlock widget for encrypted content (shared by edit page and diff panel).
/// Inputs: encrypted content + [onUnlocked] callback(context, password, plaintext).
/// Password input, decryption and error handling all happen inside this widget.
class UnlockContentWidget extends StatefulWidget {
  final String encryptedContent;
  final void Function(BuildContext context, String password, String decryptedContent) onUnlocked;

  const UnlockContentWidget({super.key, required this.encryptedContent, required this.onUnlocked});

  @override
  State<UnlockContentWidget> createState() => _UnlockContentWidgetState();
}

class _UnlockContentWidgetState extends State<UnlockContentWidget> {
  final _passwordController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // autofocus:true sometimes fails on page transition — force focus after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.enterPassword)));
      return;
    }
    final decrypted = Utils.decryptContent(widget.encryptedContent, password);
    if (decrypted == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordIncorrect)));
      return;
    }
    widget.onUnlocked(context, password, decrypted);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      // x axis 0 (center), y axis -0.3 (slightly above center)
      alignment: const Alignment(0.0, -0.2),
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 48, color: Theme.of(context).colorScheme.primary),
            SizedBox(height: 16),
            Text(l10n.recordLocked, style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 8),
            Text(
              l10n.enterPasswordToUnlock,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
            ),
            SizedBox(height: 24),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _passwordController,
                    focusNode: _focusNode,
                    autofocus: true,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: l10n.enterPassword,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key),
                    ),
                    onSubmitted: (value) => _onSubmit(),
                  ),
                  SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _onSubmit,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(l10n.unlock),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
