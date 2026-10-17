import 'dart:async';

/// 可被退出前保存刷新的目标: 由编辑页实现, 协调器仅依赖此接口而非具体页面类。
abstract class SaveFlushTarget {
  Future<void>? saveRecord();
}

/// 跨编辑页的保存协调器。
///
/// 跟踪所有当前打开的编辑页实例与进行中的保存链, 应用退出前统一触发保存
/// 并等待完成, 防止进程终止丢失异步保存。
class EditorSaveCoordinator {
  EditorSaveCoordinator._();

  /// 按 uuid 索引在飞保存链: 关闭后快速重开同一笔记时, 新页面可等待旧页面的写盘完成;
  /// flushAll 也复用此 map 等待全部在飞保存
  static final Map<String, Future<void>> _pendingByUuid = {};

  /// 当前打开的编辑器页面实例: 退出前统一触发保存
  static final Set<SaveFlushTarget> _liveEditors = {};

  /// 注册一个打开的编辑页
  static void register(SaveFlushTarget target) {
    _liveEditors.add(target);
  }

  /// 注销一个已关闭的编辑页
  static void unregister(SaveFlushTarget target) {
    _liveEditors.remove(target);
  }

  /// 跟踪一条保存链: 加入 uuid 索引, 该 Future 完成后自动移除
  static Future<void> trackSave(Future<void> future, String uuid) {
    _pendingByUuid[uuid] = future;
    return future.whenComplete(() {
      // 仅当 map 中仍指向本 future 时才移除, 避免误删链式保存注册的新 future
      if (_pendingByUuid[uuid] == future) {
        _pendingByUuid.remove(uuid);
      }
    });
  }

  /// 等待指定 uuid 的在飞保存完成 (无在飞保存则立即返回)
  static Future<void> waitPending(String uuid) async {
    final future = _pendingByUuid[uuid];
    if (future != null) await future;
  }

  /// 应用退出前全量保存: 先对所有打开的编辑页触发 saveRecord, 再等待全部 pending 保存链完成
  static Future<void> flushAll() async {
    for (final editor in _liveEditors.toList()) {
      editor.saveRecord();
    }
    while (_pendingByUuid.isNotEmpty) {
      await Future.wait(_pendingByUuid.values.toList());
    }
  }
}
