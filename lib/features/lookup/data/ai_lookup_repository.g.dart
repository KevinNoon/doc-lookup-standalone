// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_lookup_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiLookupRepository)
final aiLookupRepositoryProvider = AiLookupRepositoryProvider._();

final class AiLookupRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<AiLookupRepository>,
          AiLookupRepository,
          FutureOr<AiLookupRepository>
        >
    with
        $FutureModifier<AiLookupRepository>,
        $FutureProvider<AiLookupRepository> {
  AiLookupRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiLookupRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiLookupRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<AiLookupRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AiLookupRepository> create(Ref ref) {
    return aiLookupRepository(ref);
  }
}

String _$aiLookupRepositoryHash() =>
    r'e60e7a5572f3d63f404e47ae9908bcc74e6e4ec4';
