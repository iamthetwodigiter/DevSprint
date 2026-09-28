// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TaskNotifier)
final taskProvider = TaskNotifierProvider._();

final class TaskNotifierProvider
    extends $AsyncNotifierProvider<TaskNotifier, TaskModel?> {
  TaskNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskNotifierHash();

  @$internal
  @override
  TaskNotifier create() => TaskNotifier();
}

String _$taskNotifierHash() => r'b490436e6fe63dbb7e62e0457a35b8b4182c4b20';

abstract class _$TaskNotifier extends $AsyncNotifier<TaskModel?> {
  FutureOr<TaskModel?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<TaskModel?>, TaskModel?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<TaskModel?>, TaskModel?>,
              AsyncValue<TaskModel?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
