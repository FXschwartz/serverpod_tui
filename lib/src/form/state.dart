import 'package:serverpod_tui/src/form/config.dart';
import 'package:serverpod_tui/src/form/config_option.dart';
import 'package:serverpod_tui/src/form/requirement.dart';
import 'package:serverpod_tui/src/form/validating_text_controller.dart';

/// State for a `Form` component.
/// This manages states for text input, focus
/// and selection (single and multi).
class FormState {
  FormState(this._configValues) {
    _updateState();
  }

  /// Configurations used to initialize this state.
  final List<FormConfig> _configValues;

  /// Mutable configurations which gets updated with this state.
  final List<FormConfig> configurations = [];

  /// Tracked state for focused [FormConfigOption] per [FormSelectionConfig].
  final Map<FormSelectionConfig, _FormConfigState> _focusedOptionState = {};

  /// Tracked state for selected [FormConfigOption]s per [FormSelectionConfig].
  final Map<FormSelectionConfig, Set<FormConfigOption>> _selectionState = {};

  /// Tracked input state per [FormInputConfig].
  final Map<FormInputConfig, ValidatingTextController> _inputState = {};

  /// Persisted validators that survive config removal and recreation.
  final Map<FormInputConfig, String? Function(String)?> _validators = {};

  int _maxFocusedConfigIndex = 0;

  /// Max index of focusable configurations.
  int get maxFocusedConfigIndex => _maxFocusedConfigIndex;

  int _focusedConfigIndex = 0;

  /// Index of the current configuration in focus.
  int get focusedConfigIndex => _focusedConfigIndex;

  /// Updates internal selection and focus states
  /// and removes configurations that do not meet specified requirements.
  void _updateState() {
    configurations.clear();
    for (final config in _configValues) {
      if (_isConfigConstrained(config)) {
        _inputState.remove(config);
        _selectionState.remove(config);
        _focusedOptionState.remove(config);
        continue;
      }

      configurations.add(config);
      if (config is FormSelectionConfig) {
        _selectionState[config] ??= config.defaultOptions;
        _focusedOptionState[config] ??= _FormConfigState(config);
      } else if (config is FormInputConfig) {
        final controller = _inputState[config] ??= ValidatingTextController();
        final validator = _validators[config];
        if (validator != null) {
          controller.setValidator(validator);
        }
      }
    }

    _maxFocusedConfigIndex = configurations.length - 1;
  }

  /// Updates the focused [FormConfig] by [delta].
  void updateFocusedConfig(int delta) {
    _focusedConfigIndex += delta;
    if (_focusedConfigIndex > maxFocusedConfigIndex) {
      _focusedConfigIndex = 0;
    } else if (_focusedConfigIndex < 0) {
      _focusedConfigIndex = maxFocusedConfigIndex;
    }
  }

  /// Updates the focused [FormConfigOption] for the focused [FormConfig] by [delta].
  void updateFocusedConfigOption(int delta) {
    final config = configurations[_focusedConfigIndex];
    final configState = _focusedOptionState[config];
    configState?._updateFocusedOption(delta);
  }

  void _updateSelectedOption(
    FormSelectionConfig config,
    FormConfigOption option,
  ) {
    if (config.multiSelect) {
      final selections = _selectionState[config] ?? {};
      if (selections.contains(option)) {
        _selectionState[config] = selections.difference({option});
      } else if (config.exclusiveOptions.contains(option)) {
        _selectionState[config] = {option};
      } else {
        _selectionState[config] = {
          ...selections.difference(config.exclusiveOptions),
          option,
        };
      }
    } else {
      _selectionState[config] = {option};
    }
  }

  /// Moves focus to the previous element vertically.
  void focusUp() => updateFocusedConfig(-1);

  /// Moves focus to the next element vertically.
  void focusDown() => updateFocusedConfig(1);

  /// Moves focus to the next element horizontally.
  void focusLeft() => updateFocusedConfigOption(-1);

  /// Moves focus to the previous element horizontally.
  void focusRight() => updateFocusedConfigOption(1);

  /// Selects the element that is in focus.
  void onSelect() => selectConfigOption();

  /// Updates the selected [FormSelectionConfig] for the focused [FormConfig].
  void selectConfigOption() {
    final config = configurations[_focusedConfigIndex];
    if (config is! FormSelectionConfig) return;
    final configState = _focusedOptionState[config];
    if (configState == null) return;

    // Invert the focused option for config with boolean options
    // to select correct option since the UI only displays 'Enabled' option
    if (config.isBoolean) {
      final selectedOption = getSelectedOptionFor(config);
      final unselectedOptionIndex = config.options.indexWhere(
        (e) => e != selectedOption,
      );
      configState._focusedOptionIndex = unselectedOptionIndex;
    }

    final focusedOptionIndex = configState.focusedOptionIndex;
    final newOption = config.options[focusedOptionIndex];
    _updateSelectedOption(config, newOption);
    _updateState();
  }

  /// Requests for [config] to be in focus.
  void requestFocus(FormConfig config) {
    _focusedConfigIndex = configurations.indexOf(config);
  }

  /// Sets [option] as a selected value for [config].
  void updateSelectedOption(
    FormSelectionConfig config,
    FormConfigOption option,
  ) {
    _updateSelectedOption(config, option);
    _focusedConfigIndex = configurations.indexOf(config);
    final configState = _focusedOptionState[config];
    configState?._focusedOptionIndex = config.options.indexOf(option);
    _updateState();
  }

  /// Updates the input text for [config] with [text].
  void updateInput(FormInputConfig config, String text) {
    final controller = _inputState[config];
    controller?.text = text;
  }

  /// True when [config] is partially locked because at least one requirement
  /// on another config is not satisfied.
  bool _isConfigConstrained(FormConfig config) {
    return config.requirements.any(_isRequirementUnsatisfied);
  }

  /// True when [req] is not satisfied given current selections.
  bool _isRequirementUnsatisfied(FormRequirement req) {
    final selectedOptions = getSelectedOptionsFor(req.config);
    if (selectedOptions == null) return true;
    return selectedOptions.intersection(req.configOptions).isEmpty;
  }

  /// Returns the focused option for [config].
  int? getFocusedOptionIndexFor(FormConfig config) {
    final state = _focusedOptionState[config];
    return state?._focusedOptionIndex;
  }

  /// Returns the selected [FormConfigOption] for [config].
  /// For multi-select configs, use [getSelectedOptionsFor] instead.
  T? getSelectedOptionFor<T extends FormConfigOption>(FormConfig<T> config) {
    final value = _selectionState[config];
    return value?.firstOrNull as T?;
  }

  /// Returns all selected [FormConfigOption]s for [config].
  Set<T>? getSelectedOptionsFor<T extends FormConfigOption>(
    FormConfig<T> config,
  ) {
    return _selectionState[config]?.cast<T>();
  }

  /// Returns the current input text for [config], if any.
  String? getInputFor(FormInputConfig config) {
    return getInputControllerFor(config)?.text;
  }

  /// Returns the [ValidatingTextController] for [config], if any.
  ValidatingTextController? getInputControllerFor(FormInputConfig config) {
    return _inputState[config];
  }

  /// Sets a validator function for [config] that will run on every text change.
  /// The validator is persisted so it survives config removal and recreation
  /// when requirements are not met.
  void setValidator(
    FormInputConfig config,
    String? Function(String)? validator,
  ) {
    _validators[config] = validator;
    _inputState[config]?.setValidator(validator);
  }

  /// Returns true if [option] is a selected option for [config].
  bool isOptionSelectedForConfig<T extends FormConfigOption>(
    FormConfig<T> config,
    T option,
  ) {
    final value = _selectionState[config];
    return value?.contains(option) ?? false;
  }

  /// Disposes all resources held by this state.
  void dispose() {
    for (final controller in _inputState.values) {
      controller.dispose();
    }
    _inputState.clear();
  }
}

/// State for a multi-screen `Form` component
/// with support for screen navigation
/// and focus management for Back/Next buttons.
class MultiScreenFormState extends FormState {
  MultiScreenFormState(super._configValues);

  int _currentScreenIndex = 0;

  /// Current screen index in multi-screen mode.
  int get currentScreenIndex => _currentScreenIndex;

  /// Number of config screens visible in the form.
  int get configScreenCount => configurations.length;

  /// Whether there is only one config screen.
  bool get hasSingleScreen => configScreenCount <= 1;

  /// Whether the current screen is the summary screen.
  bool get isSummary => _currentScreenIndex >= configScreenCount;

  /// False while the current screen is missing a required selection.
  bool get canAdvance {
    if (isSummary) return true;
    final config = configurations[_currentScreenIndex];
    if (config is! FormSelectionConfig || !config.selectionRequired) {
      return true;
    }
    return getSelectedOptionsFor(config)?.isNotEmpty ?? false;
  }

  bool _focusOnButton = false;

  /// Whether the Back/Next buttons are focused in multi-screen mode.
  bool get focusOnButton => _focusOnButton;

  int _focusedButtonIndex = 0;

  /// Index of the focused button (0 = Back, 1 = Next).
  int get focusedButtonIndex => _focusedButtonIndex;

  /// Unfocus form options.
  void _unfocusOptions() {
    _focusedConfigIndex = -1;
  }

  /// Moves focus to the back button in a multi-screen flow.
  void focusBackButton() {
    _unfocusOptions();
    _focusOnButton = true;
    _focusedButtonIndex = 0;
  }

  /// Moves focus to the next button in a multi-screen flow.
  void focusNextButton() {
    _unfocusOptions();
    _focusOnButton = true;
    _focusedButtonIndex = 1;
  }

  /// Moves focus to the next element vertically.
  /// If buttons are not in focus in multi-screen flow,
  /// then the focus is moved to the buttons.
  @override
  void focusDown() {
    if (!_focusOnButton) {
      if (isSummary || _currentScreenIndex > 0) {
        focusBackButton();
      } else if (!isSummary) {
        focusNextButton();
      }
    }
  }

  /// Moves focus to the previous element vertically.
  /// If buttons are in focus in multi-screen flow,
  /// then the focus is moved to the form.
  @override
  void focusUp() {
    if (_focusOnButton) {
      _focusOnButton = false;
      if (_currentScreenIndex < configurations.length) {
        final config = configurations[_currentScreenIndex];
        requestFocus(config);
      }
    }
  }

  /// Moves focus to the next element horizontally.
  /// If buttons are in focus (only true in multi-screen flow),
  /// then the focus is moved to the next button.
  ///
  /// If buttons are not in focus (form is focused),
  /// the next form config option is focused.
  @override
  void focusRight() {
    if (_focusOnButton) {
      if (_focusedButtonIndex == 0) {
        focusNextButton();
      }
    } else if (_currentScreenIndex < configurations.length) {
      final config = configurations[_currentScreenIndex];
      requestFocus(config);
      updateFocusedConfigOption(1);
    }
  }

  /// Moves focus to the previous element horizontally.
  /// If buttons are in focus (only true in multi-screen flow),
  /// then the focus is moved to the previous button.
  ///
  /// If buttons are not in focus (form is focused),
  /// the previous form config option is focused.
  @override
  void focusLeft() {
    if (_focusOnButton) {
      if (_focusedButtonIndex == 1 && _currentScreenIndex > 0) {
        focusBackButton();
      }
    } else if (_currentScreenIndex < configurations.length) {
      final config = configurations[_currentScreenIndex];
      requestFocus(config);
      updateFocusedConfigOption(-1);
    }
  }

  /// Advances to the next screen in multi-screen mode.
  void nextScreen() {
    if (hasSingleScreen || !canAdvance) return;
    if (_currentScreenIndex < configScreenCount) {
      _currentScreenIndex++;
      _updateFormFocus();
    }
  }

  /// Goes back to the previous screen in multi-screen mode.
  void previousScreen() {
    if (hasSingleScreen) return;
    if (_currentScreenIndex > 0) {
      _currentScreenIndex--;
      _updateFormFocus();
    }
  }

  /// Selects a focused button or form option.
  /// If a button is focused, navigates to the previous/next screen.
  /// Otherwise, if a form option is focused, selects it.
  @override
  void onSelect() {
    if (_focusOnButton) {
      switch (_focusedButtonIndex) {
        case 0:
          previousScreen();
          break;
        case 1:
          nextScreen();
          break;
      }
    } else {
      selectConfigOption();
    }
  }

  /// Focus form config for the current screen.
  void _updateFormFocus() {
    _focusOnButton = false;
    if (_currentScreenIndex < configurations.length) {
      final config = configurations[_currentScreenIndex];
      requestFocus(config);
      final currentFocus = getFocusedOptionIndexFor(config) ?? 0;
      if (currentFocus > 0) {
        updateFocusedConfigOption(-currentFocus);
      }
    } else {
      // Focus action button on summary screen.
      focusNextButton();
    }
  }
}

/// Internal state tracking the focused option for a [FormConfig].
class _FormConfigState<T extends FormSelectionConfig> {
  _FormConfigState(this.config) : _maxIndex = config.options.length - 1;

  final T config;
  final int _maxIndex;

  late int _focusedOptionIndex = 0;
  int get focusedOptionIndex => _focusedOptionIndex;

  void _updateFocusedOption(int delta) {
    _focusedOptionIndex += delta;
    if (_focusedOptionIndex > _maxIndex) {
      _focusedOptionIndex = 0;
    } else if (_focusedOptionIndex < 0) {
      _focusedOptionIndex = _maxIndex;
    }
  }
}
