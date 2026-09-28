import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'task_notifier.dart';
part 'app_lifecycle_provider.g.dart';

@riverpod
class AppLifecycleNotifier extends _$AppLifecycleNotifier
    with WidgetsBindingObserver {
  int _strikes = 0;

  @override
  int build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    return 0;
  }

  void resetStrikes() {
    _strikes = 0;
    state = 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.inactive) {
      return;
    }

    if (ref.read(taskProvider).value == null) return;

    _strikes++;
    this.state = _strikes;

    if (_strikes >= 3) {
      ref
          .read(taskProvider.notifier)
          .cancelCurrentTask('Failed (Focus lost 3 times)');
      resetStrikes();
    }
  }
}
