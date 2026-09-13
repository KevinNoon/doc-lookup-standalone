// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'folder_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(folderRepository)
final folderRepositoryProvider = FolderRepositoryProvider._();

final class FolderRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<FolderRepository>,
          FolderRepository,
          FutureOr<FolderRepository>
        >
    with $FutureModifier<FolderRepository>, $FutureProvider<FolderRepository> {
  FolderRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'folderRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$folderRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<FolderRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FolderRepository> create(Ref ref) {
    return folderRepository(ref);
  }
}

String _$folderRepositoryHash() => r'0cf4afc728d0c3280c5a825d42beafc24f37aef2';

@ProviderFor(userFolders)
final userFoldersProvider = UserFoldersProvider._();

final class UserFoldersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Folder>>,
          List<Folder>,
          Stream<List<Folder>>
        >
    with $FutureModifier<List<Folder>>, $StreamProvider<List<Folder>> {
  UserFoldersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userFoldersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userFoldersHash();

  @$internal
  @override
  $StreamProviderElement<List<Folder>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Folder>> create(Ref ref) {
    return userFolders(ref);
  }
}

String _$userFoldersHash() => r'60f139b2f834ae84e53f0dffbdcf4e47e9b3c7b8';
