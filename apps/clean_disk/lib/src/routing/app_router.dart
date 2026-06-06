import 'package:clean_disk_scan/clean_disk_scan.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import 'app_routes.dart';

final class AppRouter {
  AppRouter({
    required ScanModule scanModule,
    String initialLocation = AppRoutes.scanPath,
  }) : _scanModule = scanModule,
       _initialLocation = initialLocation;

  final ScanModule _scanModule;
  final String _initialLocation;
  final RouteObserver<ModalRoute<dynamic>> routeObserver =
      RouteObserver<ModalRoute<dynamic>>();

  late final GoRouter router = GoRouter(
    initialLocation: _initialLocation,
    observers: [routeObserver],
    routes: [
      GoRoute(
        path: AppRoutes.scanPath,
        builder: (context, state) {
          return ModuleScope<ScanModule>(
            module: _scanModule,
            child: const ScanModuleHost(),
          );
        },
      ),
    ],
  );
}
