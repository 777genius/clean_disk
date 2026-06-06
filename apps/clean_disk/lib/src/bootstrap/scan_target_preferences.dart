import 'scan_target_preferences_stub.dart'
    if (dart.library.io) 'scan_target_preferences_io.dart'
    as impl;

export 'scan_target_preferences_stub.dart'
    if (dart.library.io) 'scan_target_preferences_io.dart';

final createScanTargetPreferenceStore = impl.createScanTargetPreferenceStore;
