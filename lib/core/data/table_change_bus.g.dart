// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'table_change_bus.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(tableChangeBus)
final tableChangeBusProvider = TableChangeBusProvider._();

final class TableChangeBusProvider
    extends $FunctionalProvider<TableChangeBus, TableChangeBus, TableChangeBus>
    with $Provider<TableChangeBus> {
  TableChangeBusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tableChangeBusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tableChangeBusHash();

  @$internal
  @override
  $ProviderElement<TableChangeBus> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TableChangeBus create(Ref ref) {
    return tableChangeBus(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TableChangeBus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TableChangeBus>(value),
    );
  }
}

String _$tableChangeBusHash() => r'8cb9ac89aba21cef14540ac951c0600e54f24f8e';
