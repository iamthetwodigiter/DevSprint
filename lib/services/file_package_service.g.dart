// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_package_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(filePackageService)
final filePackageServiceProvider = FilePackageServiceProvider._();

final class FilePackageServiceProvider
    extends
        $FunctionalProvider<
          FilePackageService,
          FilePackageService,
          FilePackageService
        >
    with $Provider<FilePackageService> {
  FilePackageServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'filePackageServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$filePackageServiceHash();

  @$internal
  @override
  $ProviderElement<FilePackageService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FilePackageService create(Ref ref) {
    return filePackageService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FilePackageService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FilePackageService>(value),
    );
  }
}

String _$filePackageServiceHash() =>
    r'994794b418e4a7f1122a04107379e7f35b271c9c';
