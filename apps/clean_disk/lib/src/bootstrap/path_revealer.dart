import 'path_revealer_stub.dart'
    if (dart.library.io) 'path_revealer_io.dart'
    as impl;

export 'path_revealer_stub.dart' if (dart.library.io) 'path_revealer_io.dart';

final createPathRevealer = impl.createPathRevealer;
