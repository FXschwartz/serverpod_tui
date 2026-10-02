import 'package:serverpod_tui/src/form/config_option.dart';
import 'package:serverpod_tui/src/form/requirement.dart';

/// Base configuration for a form.
sealed class FormConfig<T extends FormConfigOption> {
  /// UI visible label for this config.
  String get label;

  /// Optional description for this config.
  FormDescription? get description;

  /// Requirements for other related configs that must be satisfied
  /// for this config to be enabled.
  List<FormRequirement> get requirements;
}

/// Description for a form config.
class FormDescription {
  const FormDescription({
    required this.label,
    this.spacing = 1,
  });

  /// The description text.
  final String label;

  /// Spacing between the description and the form input in the UI.
  final double spacing;
}

/// A text input configuration for a form.
abstract interface class FormInputConfig implements FormConfig {
  /// Max lines allowed for the text input in the UI.
  int get maxLines;

  /// Width of text input in the UI.
  double get width;

  /// Optional suffix text displayed after the input value.
  String? get suffixText;
}

/// A selection configuration for a form.
abstract interface class FormSelectionConfig<T extends FormConfigOption>
    implements FormConfig<T> {
  /// Supported config options.
  List<T> get options;

  /// The default config options.
  Set<T> get defaultOptions;

  /// Whether this config supports multi-select options.
  bool get multiSelect;

  /// Options that can not be combined with any other option
  /// when [multiSelect] is true.
  Set<T> get exclusiveOptions;

  /// Whether at least one option must be selected
  /// before a form can move past this config.
  bool get selectionRequired;
}

extension FormSelectionConfigExtension on FormSelectionConfig {
  /// Whether the config has boolean options.
  bool get isBoolean => defaultOptions is Set<BoolFormConfigOption>;
}
