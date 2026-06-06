import 'package:clean_disk_scan/clean_disk_scan.dart';
import 'package:get_it/get_it.dart';

import '../routing/app_router.dart';
import 'scan_module_factory.dart';

final getIt = GetIt.instance;

void configureDependencies({GetIt? container}) {
  final registry = container ?? getIt;

  if (!registry.isRegistered<ScanModule>()) {
    registry.registerLazySingleton<ScanModule>(createScanModule);
  }

  if (!registry.isRegistered<AppRouter>()) {
    registry.registerLazySingleton<AppRouter>(
      () => AppRouter(scanModule: registry.get<ScanModule>()),
    );
  }
}
