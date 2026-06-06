import 'package:flutter/material.dart';
import 'package:headless/headless.dart';

class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.value,
    required this.values,
    required this.itemLabel,
    required this.onChanged,
    this.label,
  });

  final String? label;
  final T value;
  final List<T> values;
  final String Function(T value) itemLabel;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final field = RDropdownButton<T>(
      value: value,
      options: _buildOptions(values: values, itemLabel: itemLabel),
      onChanged: onChanged,
      placeholder: label,
      semanticLabel: label,
      variant: RDropdownVariant.outlined,
      size: RDropdownSize.large,
      style: RDropdownStyle(
        triggerTextStyle: textTheme.bodyLarge?.copyWith(letterSpacing: 0),
        triggerForegroundColor: colorScheme.onSurface,
        triggerBackgroundColor: colorScheme.surface,
        triggerBorderColor: colorScheme.outlineVariant,
        triggerIconColor: colorScheme.onSurfaceVariant,
        triggerPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        triggerMinSize: const Size.fromHeight(52),
        triggerRadius: 8,
        menuBackgroundColor: colorScheme.surface,
        menuBorderRadius: BorderRadius.circular(8),
        itemTextStyle: textTheme.bodyLarge?.copyWith(letterSpacing: 0),
      ),
    );

    if (label == null) {
      return field;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label!,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}

List<RDropdownOption<T>> _buildOptions<T>({
  required List<T> values,
  required String Function(T value) itemLabel,
}) {
  return List<RDropdownOption<T>>.generate(values.length, (index) {
    final value = values[index];
    final text = _resolveOptionText(
      value: value,
      rawText: itemLabel(value),
      index: index,
    );

    return RDropdownOption<T>(
      value: value,
      item: HeadlessListItemModel(
        id: ListboxItemId('app-select-$index'),
        primaryText: text,
        typeaheadLabel: HeadlessTypeaheadLabel.normalize(text),
      ),
    );
  }, growable: false);
}

String _resolveOptionText<T>({
  required T value,
  required String rawText,
  required int index,
}) {
  final trimmedRawText = rawText.trim();
  if (trimmedRawText.isNotEmpty) {
    return rawText;
  }

  final fallback = value.toString().trim();
  if (fallback.isNotEmpty) {
    return fallback;
  }

  return 'Option ${index + 1}';
}
