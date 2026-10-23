import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Base [State] with two conveniences:
///   - [safeSetState]: deferred setState via Timer.run (survives gesture-end).
///   - [listen]: registers a [Listenable] listener and auto-removes it on
///     [dispose]. The callback reference is captured once, so add/remove match
///     (unlike inline `() => fn()` or inline method tear-offs).
abstract class BaseState<T extends StatefulWidget> extends State<T> {
  final List<(Listenable, VoidCallback)> _listeners = [];

  /// Register [listener] on [notifier]; removed automatically on [dispose].
  @protected
  void listen(Listenable notifier, VoidCallback listener) {
    notifier.addListener(listener);
    _listeners.add((notifier, listener));
  }

  /// Deferred setState via Timer.run (microtask) — fires reliably even after
  /// native gesture end where addPostFrameCallback may never fire.
  @protected
  void safeSetState([VoidCallback? fn]) {
    if (!mounted) return;
    final fn0 = fn ?? () {};
    Timer.run(() {
      if (!mounted) return;
      setState(fn0);
    });
  }

  @override
  void dispose() {
    for (final (notifier, listener) in _listeners) {
      notifier.removeListener(listener);
    }
    _listeners.clear();
    super.dispose();
  }
}
