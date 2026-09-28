// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evaluation_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EvaluationNotifier)
final evaluationProvider = EvaluationNotifierProvider._();

final class EvaluationNotifierProvider
    extends $AsyncNotifierProvider<EvaluationNotifier, EvaluationModel?> {
  EvaluationNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'evaluationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$evaluationNotifierHash();

  @$internal
  @override
  EvaluationNotifier create() => EvaluationNotifier();
}

String _$evaluationNotifierHash() =>
    r'9e6c3ec703ef44867006352943d7016226b2dc20';

abstract class _$EvaluationNotifier extends $AsyncNotifier<EvaluationModel?> {
  FutureOr<EvaluationModel?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<EvaluationModel?>, EvaluationModel?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<EvaluationModel?>, EvaluationModel?>,
              AsyncValue<EvaluationModel?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
