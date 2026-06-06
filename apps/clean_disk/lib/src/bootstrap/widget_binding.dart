import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

void ensureCleanDiskWidgetsBinding() {
  if (kDebugMode && BindingBase.debugBindingType() == null) {
    MarionetteBinding.ensureInitialized(
      MarionetteConfiguration(
        isInteractiveWidget: _isInteractiveWidget,
        extractText: _extractText,
        maxScreenshotSize: null,
      ),
    );
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();
}

bool _isInteractiveWidget(Type type) {
  return type == AppButton ||
      type == AppGradientButton ||
      type == AppIconButton ||
      type == AppOutlinedActionButton ||
      type == AppOutlinePillButton ||
      type == AppSelectField ||
      type == AppTapSurface ||
      type == AppTextActionButton ||
      type == AppTextField;
}

String? _extractText(Element element) {
  final widget = element.widget;

  if (widget is AppButton) {
    return widget.label;
  }
  if (widget is AppGradientButton) {
    return widget.label;
  }
  if (widget is AppIconButton) {
    return widget.tooltip;
  }
  if (widget is AppSelectField) {
    return widget.label;
  }
  if (widget is AppTapSurface) {
    return widget.semanticLabel;
  }
  if (widget is AppTextActionButton) {
    return widget.label;
  }
  if (widget is AppTextField) {
    return widget.controller.text.isEmpty
        ? widget.placeholder ?? widget.label
        : widget.controller.text;
  }

  return null;
}
