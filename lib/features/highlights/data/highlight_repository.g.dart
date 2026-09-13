// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'highlight_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(highlightRepository)
final highlightRepositoryProvider = HighlightRepositoryProvider._();

final class HighlightRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<HighlightRepository>,
          HighlightRepository,
          FutureOr<HighlightRepository>
        >
    with
        $FutureModifier<HighlightRepository>,
        $FutureProvider<HighlightRepository> {
  HighlightRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'highlightRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$highlightRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<HighlightRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<HighlightRepository> create(Ref ref) {
    return highlightRepository(ref);
  }
}

String _$highlightRepositoryHash() =>
    r'49a0489a02f280e69e127ba896424c46bb75f61e';

@ProviderFor(documentHighlights)
final documentHighlightsProvider = DocumentHighlightsFamily._();

final class DocumentHighlightsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Highlight>>,
          List<Highlight>,
          Stream<List<Highlight>>
        >
    with $FutureModifier<List<Highlight>>, $StreamProvider<List<Highlight>> {
  DocumentHighlightsProvider._({
    required DocumentHighlightsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'documentHighlightsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$documentHighlightsHash();

  @override
  String toString() {
    return r'documentHighlightsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Highlight>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Highlight>> create(Ref ref) {
    final argument = this.argument as String;
    return documentHighlights(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DocumentHighlightsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$documentHighlightsHash() =>
    r'7bc3f7b028bd1348e5cf5b64e21cd8b9c2101e2b';

final class DocumentHighlightsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Highlight>>, String> {
  DocumentHighlightsFamily._()
    : super(
        retry: null,
        name: r'documentHighlightsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DocumentHighlightsProvider call(String documentId) =>
      DocumentHighlightsProvider._(argument: documentId, from: this);

  @override
  String toString() => r'documentHighlightsProvider';
}

@ProviderFor(userHighlights)
final userHighlightsProvider = UserHighlightsProvider._();

final class UserHighlightsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Highlight>>,
          List<Highlight>,
          Stream<List<Highlight>>
        >
    with $FutureModifier<List<Highlight>>, $StreamProvider<List<Highlight>> {
  UserHighlightsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userHighlightsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userHighlightsHash();

  @$internal
  @override
  $StreamProviderElement<List<Highlight>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Highlight>> create(Ref ref) {
    return userHighlights(ref);
  }
}

String _$userHighlightsHash() => r'0824b72d6e0100d233832977b123a1fee30b40e1';
