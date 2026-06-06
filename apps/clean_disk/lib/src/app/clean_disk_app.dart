import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:clean_disk_localization/clean_disk_localization.dart';
import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../routing/app_router.dart';

class CleanDiskApp extends StatelessWidget {
  const CleanDiskApp({super.key, required this.appRouter});

  final AppRouter appRouter;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.light();
    final darkTheme = AppTheme.dark();
    const themeMode = ThemeMode.system;

    return ModularityRoot(
      observer: appRouter.routeObserver,
      child: AppHeadlessScope(
        theme: theme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        appBuilder: (overlayBuilder) {
          return MaterialApp.router(
            title: 'Clean Disk',
            onGenerateTitle: (context) => context.cleanDiskL10n.appTitle,
            debugShowCheckedModeBanner: false,
            theme: theme,
            darkTheme: darkTheme,
            themeMode: themeMode,
            localizationsDelegates:
                CleanDiskLocalizations.localizationsDelegates,
            supportedLocales: CleanDiskLocalizations.supportedLocales,
            routerConfig: appRouter.router,
            builder: overlayBuilder,
          );
        },
      ),
    );
  }
}
