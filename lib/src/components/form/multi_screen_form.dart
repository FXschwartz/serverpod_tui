import 'package:nocterm/nocterm.dart';
import 'package:serverpod_tui/src/components/form/configuration.dart';
import 'package:serverpod_tui/src/components/form/form.dart';
import 'package:serverpod_tui/src/components/text_button.dart';
import 'package:serverpod_tui/src/components/wrap.dart';
import 'package:serverpod_tui/src/form/config.dart';
import 'package:serverpod_tui/src/form/config_option.dart';
import 'package:serverpod_tui/src/form/state.dart';

/// A multi screen form component
/// that renders a screen for each config in [state]
/// with a summary screen at the end.
class MultiScreenForm extends Form {
  const MultiScreenForm({
    super.key,
    required this.state,
    required super.scrollController,
    required super.rebuild,
    super.spacing = 1,
    super.padding = const EdgeInsets.symmetric(horizontal: 1),
    this.backButtonActivationKey = LogicalKey.space,
    this.nextButtonActivationKey = LogicalKey.space,
    super.onSubmit,
    this.summaryDescription,
    this.submitButtonLabel,
  }) : super(state: state);

  /// State for multi screen form.
  final MultiScreenFormState state;

  /// Activation key for the back button.
  final LogicalKey backButtonActivationKey;

  /// Activation key for the next button.
  final LogicalKey nextButtonActivationKey;

  /// Optional description for the summary screen.
  final String? summaryDescription;

  /// Optional label for the summary screen action button.
  /// Defaults to 'Submit' when not provided.
  final String? submitButtonLabel;

  @override
  Component build(BuildContext context) {
    if (state.isSummary) {
      return _SummaryScreen(
        state: state,
        rebuild: rebuild,
        padding: padding,
        description: summaryDescription,
        scrollController: scrollController,
        onSubmit: onSubmit,
        backButtonActivationKey: backButtonActivationKey,
        nextButtonActivationKey: nextButtonActivationKey,
        submitButtonLabel: submitButtonLabel,
      );
    }

    final config = state.configurations[state.currentScreenIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Scrollbar(
            controller: scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: padding,
                child: FormConfiguration(
                  state: state,
                  config: config,
                  focused: !state.focusOnButton,
                  rebuild: rebuild,
                  onFormInputSubmit: onSubmit,
                  onFormInputArrowUp: () {
                    state.focusUp();
                    rebuild();
                  },
                  onFormInputArrowDown: () {
                    state.focusDown();
                    rebuild();
                  },
                ),
              ),
            ),
          ),
        ),
        _MultiScreenNavigationButtons(
          state: state,
          rebuild: rebuild,
          backButtonActivationKey: backButtonActivationKey,
          nextButtonActivationKey: nextButtonActivationKey,
          onSubmit: onSubmit,
          submitButtonLabel: submitButtonLabel,
        ),
      ],
    );
  }
}

class _MultiScreenNavigationButtons extends StatelessComponent {
  const _MultiScreenNavigationButtons({
    required this.state,
    required this.rebuild,
    required this.backButtonActivationKey,
    required this.nextButtonActivationKey,
    this.onSubmit,
    this.submitButtonLabel,
  });

  final MultiScreenFormState state;
  final VoidCallback rebuild;
  final LogicalKey backButtonActivationKey;
  final LogicalKey nextButtonActivationKey;
  final VoidCallback? onSubmit;

  /// Label for the button to submit the form.
  /// Defaults to 'Submit'.
  final String? submitButtonLabel;

  @override
  Component build(BuildContext context) {
    final isFirstScreen = state.currentScreenIndex == 0;
    final onLastScreen = state.hasSingleScreen || state.isSummary;

    return Align(
      alignment: Alignment.bottomRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFirstScreen) ...[
            TextButton(
              name: 'Back',
              activationKeys: [backButtonActivationKey],
              onActivate: (_) {
                state.previousScreen();
                rebuild();
              },
              focused: state.focusOnButton && state.focusedButtonIndex == 0,
            ),
            const SizedBox(width: 1),
          ],
          TextButton(
            name: onLastScreen ? submitButtonLabel ?? 'Submit' : 'Next',
            activationKeys: [nextButtonActivationKey],
            onActivate: (_) {
              if (onLastScreen) {
                onSubmit?.call();
              } else {
                state.nextScreen();
              }
              rebuild();
            },
            enabled: state.canAdvance,
            focused: state.focusOnButton && state.focusedButtonIndex == 1,
          ),
          const SizedBox(width: 1),
        ],
      ),
    );
  }
}

class _SummaryScreen extends StatelessComponent {
  const _SummaryScreen({
    required this.state,
    required this.rebuild,
    required this.padding,
    required this.scrollController,
    this.description,
    this.onSubmit,
    this.backButtonActivationKey = LogicalKey.space,
    this.nextButtonActivationKey = LogicalKey.space,
    this.submitButtonLabel,
  });

  final MultiScreenFormState state;
  final VoidCallback rebuild;
  final EdgeInsets padding;
  final ScrollController scrollController;
  final String? description;
  final VoidCallback? onSubmit;
  final LogicalKey backButtonActivationKey;
  final LogicalKey nextButtonActivationKey;
  final String? submitButtonLabel;

  @override
  Component build(BuildContext context) {
    final configs = state.configurations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Scrollbar(
            controller: scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final config in configs)
                      _SummaryItem(state: state, config: config),
                    if (description case String description) ...[
                      const SizedBox(height: 1),
                      Text(
                        description,
                        style: TextStyle(
                          color: Color.defaultColor,
                          fontWeight: FontWeight.dim,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        _MultiScreenNavigationButtons(
          state: state,
          rebuild: rebuild,
          backButtonActivationKey: backButtonActivationKey,
          nextButtonActivationKey: nextButtonActivationKey,
          onSubmit: onSubmit,
          submitButtonLabel: submitButtonLabel,
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessComponent {
  const _SummaryItem({
    required this.state,
    required this.config,
  });

  final MultiScreenFormState state;
  final FormConfig config;

  @override
  Component build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 1),
      child: Wrap(
        children: [
          Text(
            '• ${config.label}: ',
            style: const TextStyle(color: Color.defaultColor),
          ),
          Text(
            _value,
            style: const TextStyle(color: Color.defaultColor),
          ),
        ],
      ),
    );
  }

  String _getSelectionValue(FormSelectionConfig config) {
    if (config.multiSelect) {
      final options = state.getSelectedOptionsFor(config) ?? {};
      final values = options.map((op) => op.label).join(', ');
      return values.isEmpty ? 'None' : values;
    } else {
      final option = state.getSelectedOptionFor(config);
      if (config.isBoolean) {
        return option == BoolFormConfigOption.enabled ? 'Enabled' : 'Disabled';
      }
      return option?.label ?? 'None';
    }
  }

  String get _value {
    return switch (config) {
      FormInputConfig config => state.getInputFor(config) ?? '',
      FormSelectionConfig config => _getSelectionValue(config),
    };
  }
}
