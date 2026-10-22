import 'dart:async';

import 'package:flutter/widgets.dart';

extension StateExt on State {
  /// Deferred setState via Timer.run (microtask) — fires reliably even after
  /// native gesture end where addPostFrameCallback may never fire.
  void safeSetState([VoidCallback? fn]) {
    if (!mounted) return;
    final fn0 = fn ?? () {};
    Timer.run(() {
      if (!mounted) return;
      // ignore: invalid_use_of_protected_member
      setState(fn0);
    });
  }
}
