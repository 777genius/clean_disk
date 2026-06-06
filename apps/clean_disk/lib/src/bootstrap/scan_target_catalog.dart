import 'scan_target_catalog_stub.dart'
    if (dart.library.io) 'scan_target_catalog_io.dart'
    as impl;

export 'scan_target_catalog_stub.dart'
    if (dart.library.io) 'scan_target_catalog_io.dart';

final createScanTargetCatalog = impl.createScanTargetCatalog;
