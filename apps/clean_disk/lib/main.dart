import 'package:flutter/widgets.dart';

import 'src/app/clean_disk_app.dart';
import 'src/bootstrap/di.dart';
import 'src/bootstrap/widget_binding.dart';
import 'src/routing/app_router.dart';

Future<void> main() async {
  ensureCleanDiskWidgetsBinding();

  configureDependencies();

  runApp(CleanDiskApp(appRouter: getIt<AppRouter>()));
}
