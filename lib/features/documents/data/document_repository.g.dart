// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(documentRepository)
final documentRepositoryProvider = DocumentRepositoryProvider._();

final class DocumentRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<DocumentRepository>,
          DocumentRepository,
          FutureOr<DocumentRepository>
        >
    with
        $FutureModifier<DocumentRepository>,
        $FutureProvider<DocumentRepository> {
  DocumentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'documentRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$documentRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<DocumentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DocumentRepository> create(Ref ref) {
    return documentRepository(ref);
  }
}

String _$documentRepositoryHash() =>
    r'5daf4b7bc54514d52faf42f702e14a45220a5e45';

@ProviderFor(userDocuments)
final userDocumentsProvider = UserDocumentsProvider._();

final class UserDocumentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Document>>,
          List<Document>,
          Stream<List<Document>>
        >
    with $FutureModifier<List<Document>>, $StreamProvider<List<Document>> {
  UserDocumentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userDocumentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userDocumentsHash();

  @$internal
  @override
  $StreamProviderElement<List<Document>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Document>> create(Ref ref) {
    return userDocuments(ref);
  }
}

String _$userDocumentsHash() => r'280f74a149daa9f2a11208c906b36b8cfbdbeb8b';
