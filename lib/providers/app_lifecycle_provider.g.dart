// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_lifecycle_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppLifecycleNotifier)
final appLifecycleProvider = AppLifecycleNotifierProvider._();

final class AppLifecycleNotifierProvider
    extends $NotifierProvider<AppLifecycleNotifier, int> {
  AppLifecycleNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLifecycleProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLifecycleNotifierHash();

  @$internal
  @override
  AppLifecycleNotifier create() => AppLifecycleNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$appLifecycleNotifierHash() =>
    r'960fea6c51a5e1bef8d9bc5e72057ab20389d509';

abstract class _$AppLifecycleNotifier extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
