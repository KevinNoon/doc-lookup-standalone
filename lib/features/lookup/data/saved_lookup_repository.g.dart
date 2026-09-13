// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_lookup_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(savedLookupRepository)
final savedLookupRepositoryProvider = SavedLookupRepositoryProvider._();

final class SavedLookupRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<SavedLookupRepository>,
          SavedLookupRepository,
          FutureOr<SavedLookupRepository>
        >
    with
        $FutureModifier<SavedLookupRepository>,
        $FutureProvider<SavedLookupRepository> {
  SavedLookupRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedLookupRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedLookupRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<SavedLookupRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SavedLookupRepository> create(Ref ref) {
    return savedLookupRepository(ref);
  }
}

String _$savedLookupRepositoryHash() =>
    r'cfe9a94cdededacf0ff95ac4b9dd204cd66af4f9';

@ProviderFor(userSavedLookups)
final userSavedLookupsProvider = UserSavedLookupsProvider._();

final class UserSavedLookupsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SavedLookup>>,
          List<SavedLookup>,
          Stream<List<SavedLookup>>
        >
    with
        $FutureModifier<List<SavedLookup>>,
        $StreamProvider<List<SavedLookup>> {
  UserSavedLookupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userSavedLookupsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userSavedLookupsHash();

  @$internal
  @override
  $StreamProviderElement<List<SavedLookup>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SavedLookup>> create(Ref ref) {
    return userSavedLookups(ref);
  }
}

String _$userSavedLookupsHash() => r'1ff1a12422275470f8eb843972883cba0e20ab06';
