import 'package:clean_disk_scan/src/presentation/pages/scan_home_page.dart';
import 'package:clean_disk_scan/src/presentation/stores/scan_workspace_store.dart';
import 'package:flutter/widgets.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

final class ScanModuleHost extends StatelessWidget {
  const ScanModuleHost({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(
      context,
      listen: false,
    ).get<ScanWorkspaceStore>();
    final config = ModuleProvider.of(
      context,
      listen: false,
    ).get<ScanWorkspaceConfig>();
    return ScanHomePage(store: store, config: config);
  }
}
