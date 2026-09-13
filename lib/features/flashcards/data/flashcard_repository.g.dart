// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flashcard_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(flashcardRepository)
final flashcardRepositoryProvider = FlashcardRepositoryProvider._();

final class FlashcardRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<FlashcardRepository>,
          FlashcardRepository,
          FutureOr<FlashcardRepository>
        >
    with
        $FutureModifier<FlashcardRepository>,
        $FutureProvider<FlashcardRepository> {
  FlashcardRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'flashcardRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$flashcardRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<FlashcardRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FlashcardRepository> create(Ref ref) {
    return flashcardRepository(ref);
  }
}

String _$flashcardRepositoryHash() =>
    r'2a2ceb04335bff26d2d935c1bb590849c9644f6f';

@ProviderFor(dueFlashcards)
final dueFlashcardsProvider = DueFlashcardsProvider._();

final class DueFlashcardsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Flashcard>>,
          List<Flashcard>,
          Stream<List<Flashcard>>
        >
    with $FutureModifier<List<Flashcard>>, $StreamProvider<List<Flashcard>> {
  DueFlashcardsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dueFlashcardsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dueFlashcardsHash();

  @$internal
  @override
  $StreamProviderElement<List<Flashcard>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Flashcard>> create(Ref ref) {
    return dueFlashcards(ref);
  }
}

String _$dueFlashcardsHash() => r'9dcf521f3de52de38106842c508177da2149b736';

@ProviderFor(dueFlashcardCount)
final dueFlashcardCountProvider = DueFlashcardCountProvider._();

final class DueFlashcardCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  DueFlashcardCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dueFlashcardCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dueFlashcardCountHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return dueFlashcardCount(ref);
  }
}

String _$dueFlashcardCountHash() => r'68621a3b5bf089b3a40796cf59b99cf926b8d47d';
